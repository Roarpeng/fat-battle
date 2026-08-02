package api

import (
	"errors"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"

	"fatbattle/backend/internal/middleware"
	"fatbattle/backend/internal/model"
)

// registerHandler 注册：bcrypt 存密码哈希，返回 token 对
func registerHandler(pool *pgxpool.Pool, jwtSecret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		if pool == nil {
			jsonError(c, http.StatusServiceUnavailable, "数据库未就绪，请检查 Docker 服务")
			return
		}
		var req model.RegisterRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			jsonError(c, http.StatusBadRequest, "参数错误: "+err.Error())
			return
		}

		hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), 10)
		if err != nil {
			jsonError(c, http.StatusInternalServerError, "密码加密失败")
			return
		}

		var userID int64
		err = pool.QueryRow(c.Request.Context(),
			`INSERT INTO users (email, nickname, pass_hash) VALUES ($1, $2, $3) RETURNING id`,
			req.Email, req.Nickname, string(hash),
		).Scan(&userID)

		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" { // unique_violation
			jsonError(c, http.StatusConflict, "该邮箱已注册")
			return
		}
		if err != nil {
			jsonError(c, http.StatusInternalServerError, "注册失败: "+err.Error())
			return
		}

		c.JSON(http.StatusCreated, gin.H{
			"user":  model.User{ID: userID, Email: req.Email, Nickname: req.Nickname},
			"token": issueTokens(jwtSecret, userID),
		})
	}
}

// loginHandler 账号密码登录
func loginHandler(pool *pgxpool.Pool, jwtSecret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		if pool == nil {
			jsonError(c, http.StatusServiceUnavailable, "数据库未就绪")
			return
		}
		var req model.LoginRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			jsonError(c, http.StatusBadRequest, "参数错误: "+err.Error())
			return
		}

		var u model.User
		err := pool.QueryRow(c.Request.Context(),
			`SELECT id, email, nickname, pass_hash, COALESCE(avatar_url, ''), created_at FROM users WHERE email = $1`,
			req.Email,
		).Scan(&u.ID, &u.Email, &u.Nickname, &u.PassHash, &u.AvatarURL, &u.CreatedAt)
		if errors.Is(err, pgx.ErrNoRows) {
			jsonError(c, http.StatusUnauthorized, "账号或密码错误")
			return
		}
		if err != nil {
			jsonError(c, http.StatusInternalServerError, "查询失败")
			return
		}
		if bcrypt.CompareHashAndPassword([]byte(u.PassHash), []byte(req.Password)) != nil {
			jsonError(c, http.StatusUnauthorized, "账号或密码错误")
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"user":  u,
			"token": issueTokens(jwtSecret, u.ID),
		})
	}
}

// refreshHandler 用 refresh token 换新 access token
func refreshHandler(_ *pgxpool.Pool, jwtSecret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		var body struct {
			RefreshToken string `json:"refreshToken" binding:"required"`
		}
		if err := c.ShouldBindJSON(&body); err != nil {
			jsonError(c, http.StatusBadRequest, "缺少 refreshToken")
			return
		}
		token, err := jwt.Parse(body.RefreshToken, func(t *jwt.Token) (interface{}, error) {
			if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, jwt.ErrSignatureInvalid
			}
			return []byte(jwtSecret), nil
		})
		if err != nil || !token.Valid {
			jsonError(c, http.StatusUnauthorized, "refresh token 无效")
			return
		}
		claims, ok := token.Claims.(jwt.MapClaims)
		if !ok {
			jsonError(c, http.StatusUnauthorized, "refresh token 无效")
			return
		}
		userID, ok := claims["sub"].(float64)
		if !ok {
			jsonError(c, http.StatusUnauthorized, "refresh token 无效")
			return
		}
		c.JSON(http.StatusOK, gin.H{"token": issueTokens(jwtSecret, int64(userID))})
	}
}

// logoutHandler 登出（MVP：客户端丢弃 token；正式版接 Redis 黑名单）
func logoutHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"ok": true})
	}
}

// meHandler 当前用户资料
func meHandler(pool *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		if pool == nil {
			jsonError(c, http.StatusServiceUnavailable, "数据库未就绪")
			return
		}
		userID := c.GetInt64("userID")
		var u model.User
		err := pool.QueryRow(c.Request.Context(),
			`SELECT id, email, nickname, COALESCE(avatar_url, ''), created_at FROM users WHERE id = $1`,
			userID,
		).Scan(&u.ID, &u.Email, &u.Nickname, &u.AvatarURL, &u.CreatedAt)
		if errors.Is(err, pgx.ErrNoRows) {
			jsonError(c, http.StatusNotFound, "用户不存在")
			return
		}
		if err != nil {
			jsonError(c, http.StatusInternalServerError, "查询失败")
			return
		}
		c.JSON(http.StatusOK, gin.H{"user": u})
	}
}

// deleteAccountHandler 账号注销（软删：标记 deleted_at，30 天后物理清理）
func deleteAccountHandler(pool *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		if pool == nil {
			jsonError(c, http.StatusServiceUnavailable, "数据库未就绪")
			return
		}
		userID := c.GetInt64("userID")
		_, err := pool.Exec(c.Request.Context(),
			`UPDATE users SET deleted_at = NOW() WHERE id = $1 AND deleted_at IS NULL`, userID)
		if err != nil {
			jsonError(c, http.StatusInternalServerError, "注销失败")
			return
		}
		c.JSON(http.StatusOK, gin.H{
			"ok":      true,
			"message": "账号已注销，数据将在 30 天后清除",
		})
	}
}

// issueTokens 签发 access(2h) + refresh(30d)
func issueTokens(secret string, userID int64) model.TokenPair {
	access, _ := middleware.SignToken(secret, userID)
	now := time.Now()
	refresh, _ := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"sub": userID,
		"exp": now.Add(30 * 24 * time.Hour).Unix(),
		"iat": now.Unix(),
	}).SignedString([]byte(secret))
	return model.TokenPair{
		AccessToken:  access,
		RefreshToken: refresh,
		ExpiresIn:    2 * 60 * 60,
	}
}

func jsonError(c *gin.Context, code int, msg string) {
	c.JSON(code, gin.H{"error": msg})
}
