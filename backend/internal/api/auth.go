package api

import (
	"errors"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"

	"fatbattle/backend/internal/middleware"
	"fatbattle/backend/internal/model"
	"fatbattle/backend/internal/repo"
	"fatbattle/backend/internal/tokenstore"
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
		_ = repo.EnsureProfile(c.Request.Context(), pool, userID, req.Nickname)

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
		var isDisabled bool
		err := pool.QueryRow(c.Request.Context(),
			`SELECT id, email, nickname, pass_hash, COALESCE(avatar_url, ''), created_at, is_disabled
			 FROM users WHERE email = $1 AND deleted_at IS NULL`,
			req.Email,
		).Scan(&u.ID, &u.Email, &u.Nickname, &u.PassHash, &u.AvatarURL, &u.CreatedAt, &isDisabled)
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
		if isDisabled {
			jsonError(c, http.StatusForbidden, "账号已被禁用")
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"user":  u,
			"token": issueTokens(jwtSecret, u.ID),
		})
	}
}

// refreshHandler 用 refresh token 换新 access token；已拉黑的 refresh 拒绝续期
func refreshHandler(jwtSecret string, dl tokenstore.Denylist) gin.HandlerFunc {
	if dl == nil {
		dl = tokenstore.Nop{}
	}
	return func(c *gin.Context) {
		var body struct {
			RefreshToken string `json:"refreshToken" binding:"required"`
		}
		if err := c.ShouldBindJSON(&body); err != nil {
			jsonError(c, http.StatusBadRequest, "缺少 refreshToken")
			return
		}
		meta, err := middleware.ParseTokenMeta(jwtSecret, body.RefreshToken)
		if err != nil {
			jsonError(c, http.StatusUnauthorized, "refresh token 无效")
			return
		}
		denied, err := dl.Denied(c.Request.Context(), meta.ID)
		if err != nil {
			log.Printf("[auth] 黑名单查询失败: %v", err)
		} else if denied {
			jsonError(c, http.StatusUnauthorized, "refresh token 已登出")
			return
		}
		// 旋转：旧 refresh 立即作废
		_ = denyToken(c, dl, meta)
		c.JSON(http.StatusOK, gin.H{"token": issueTokens(jwtSecret, meta.UserID)})
	}
}

// logoutHandler 将 access（Authorization）与 body.refreshToken 写入 Redis 黑名单
func logoutHandler(jwtSecret string, dl tokenstore.Denylist) gin.HandlerFunc {
	if dl == nil {
		dl = tokenstore.Nop{}
	}
	return func(c *gin.Context) {
		if raw := c.GetHeader("Authorization"); strings.HasPrefix(raw, "Bearer ") {
			if meta, err := middleware.ParseTokenMeta(jwtSecret, strings.TrimPrefix(raw, "Bearer ")); err == nil {
				_ = denyToken(c, dl, meta)
			}
		}
		var body struct {
			RefreshToken string `json:"refreshToken"`
		}
		_ = c.ShouldBindJSON(&body)
		if body.RefreshToken != "" {
			if meta, err := middleware.ParseTokenMeta(jwtSecret, body.RefreshToken); err == nil {
				_ = denyToken(c, dl, meta)
			}
		}
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
			`SELECT id, email, nickname, COALESCE(avatar_url, ''), created_at FROM users WHERE id = $1 AND deleted_at IS NULL`,
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
		repo.TouchLastSeen(c.Request.Context(), pool, userID)
		profile, _ := repo.GetProfile(c.Request.Context(), pool, userID)
		c.JSON(http.StatusOK, gin.H{"user": u, "profile": profile})
	}
}

// putMeHandler PUT /user/me：更新档案（从 User JSON / 运营字段 upsert）
func putMeHandler(pool *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		if pool == nil {
			jsonError(c, http.StatusServiceUnavailable, "数据库未就绪")
			return
		}
		var body map[string]any
		if err := c.ShouldBindJSON(&body); err != nil {
			jsonError(c, http.StatusBadRequest, "参数错误")
			return
		}
		userID := c.GetInt64("userID")
		fields := map[string]any{}
		allow := map[string]bool{
			"nickname": true, "avatar": true, "age": true, "gender": true,
			"heightCm": true, "weightKg": true, "targetWeightKg": true, "bmi": true,
			"sleepType": true, "workType": true, "exerciseTime": true, "characterStyle": true,
			"difficulty": true, "fitnessLevel": true, "pushupCount": true,
			"runDurationMin": true, "weeklyFreq": true, "visualTheme": true, "sculptLine": true,
			"kneeIssue": true, "waistIssue": true, "targetCal": true, "calorieFloor": true,
		}
		// 兼容 App User.toJson 字段名
		alias := map[string]string{
			"height": "heightCm", "weight": "weightKg", "targetWeight": "targetWeightKg",
			"runDuration": "runDurationMin",
		}
		for k, v := range body {
			if nk, ok := alias[k]; ok {
				k = nk
			}
			if allow[k] {
				fields[k] = v
			}
		}
		if nick, ok := fields["nickname"].(string); ok && nick != "" {
			_, _ = pool.Exec(c.Request.Context(),
				`UPDATE users SET nickname = $1 WHERE id = $2 AND deleted_at IS NULL`, nick, userID)
		}
		if err := repo.PatchProfile(c.Request.Context(), pool, userID, fields); err != nil {
			jsonError(c, http.StatusInternalServerError, "更新失败")
			return
		}
		repo.TouchLastSeen(c.Request.Context(), pool, userID)
		profile, _ := repo.GetProfile(c.Request.Context(), pool, userID)
		c.JSON(http.StatusOK, gin.H{"ok": true, "profile": profile})
	}
}

// deleteAccountHandler 账号注销（软删：标记 deleted_at，30 天后物理清理）
func deleteAccountHandler(pool *pgxpool.Pool, jwtSecret string, dl tokenstore.Denylist) gin.HandlerFunc {
	if dl == nil {
		dl = tokenstore.Nop{}
	}
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
		if raw := c.GetHeader("Authorization"); strings.HasPrefix(raw, "Bearer ") {
			if meta, err := middleware.ParseTokenMeta(jwtSecret, strings.TrimPrefix(raw, "Bearer ")); err == nil {
				_ = denyToken(c, dl, meta)
			}
		}
		c.JSON(http.StatusOK, gin.H{
			"ok":      true,
			"message": "账号已注销，数据将在 30 天后清除",
		})
	}
}

func denyToken(c *gin.Context, dl tokenstore.Denylist, meta *middleware.TokenMeta) error {
	if meta == nil {
		return nil
	}
	ttl := time.Until(meta.Exp)
	if err := dl.Deny(c.Request.Context(), meta.ID, ttl); err != nil {
		log.Printf("[auth] 写入登出黑名单失败: %v", err)
		return err
	}
	return nil
}

// issueTokens 签发 access(2h) + refresh(30d)，均含 jti 以便登出拉黑
func issueTokens(secret string, userID int64) model.TokenPair {
	access, _ := middleware.SignToken(secret, userID)
	refresh, _ := middleware.SignRefreshToken(secret, userID)
	return model.TokenPair{
		AccessToken:  access,
		RefreshToken: refresh,
		ExpiresIn:    2 * 60 * 60,
	}
}

func jsonError(c *gin.Context, code int, msg string) {
	c.JSON(code, gin.H{"error": msg})
}
