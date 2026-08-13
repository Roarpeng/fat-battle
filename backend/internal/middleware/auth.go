package middleware

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"

	"fatbattle/backend/internal/tokenstore"
)

// TokenMeta 从已签名 JWT 抽出的登出/鉴权元数据
type TokenMeta struct {
	UserID int64
	ID     string // jti，旧 token 无 jti 时用 sha256(raw)
	Exp    time.Time
	Raw    string
}

func newJTI() string {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return hex.EncodeToString([]byte(time.Now().Format(time.RFC3339Nano)))
	}
	return hex.EncodeToString(b)
}

func tokenID(claims jwt.MapClaims, raw string) string {
	if jti, ok := claims["jti"].(string); ok && jti != "" {
		return jti
	}
	sum := sha256.Sum256([]byte(raw))
	return hex.EncodeToString(sum[:])
}

// ParseTokenMeta 校验签名并返回 userID / token id / 过期时间。
func ParseTokenMeta(secret, tokenStr string) (*TokenMeta, error) {
	token, err := jwt.Parse(tokenStr, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, jwt.ErrSignatureInvalid
		}
		return []byte(secret), nil
	})
	if err != nil || token == nil || !token.Valid {
		if err == nil {
			err = jwt.ErrTokenUnverifiable
		}
		return nil, err
	}
	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return nil, jwt.ErrTokenInvalidClaims
	}
	userID, ok := claims["sub"].(float64)
	if !ok {
		return nil, jwt.ErrTokenInvalidClaims
	}
	exp := time.Time{}
	if expUnix, err := claims.GetExpirationTime(); err == nil && expUnix != nil {
		exp = expUnix.Time
	}
	return &TokenMeta{
		UserID: int64(userID),
		ID:     tokenID(claims, tokenStr),
		Exp:    exp,
		Raw:    tokenStr,
	}, nil
}

func bearerToken(c *gin.Context) string {
	header := c.GetHeader("Authorization")
	if !strings.HasPrefix(header, "Bearer ") {
		return ""
	}
	return strings.TrimPrefix(header, "Bearer ")
}

// Auth 验证 Bearer token，注入 userID；若在登出黑名单则 401。
func Auth(secret string, dl tokenstore.Denylist) gin.HandlerFunc {
	if dl == nil {
		dl = tokenstore.Nop{}
	}
	return func(c *gin.Context) {
		tokenStr := bearerToken(c)
		if tokenStr == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "缺少令牌"})
			return
		}
		meta, err := ParseTokenMeta(secret, tokenStr)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "令牌无效或已过期"})
			return
		}
		denied, err := dl.Denied(c.Request.Context(), meta.ID)
		if err != nil {
			log.Printf("[auth] 黑名单查询失败（放行）: %v", err)
		} else if denied {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "令牌已登出"})
			return
		}
		c.Set("userID", meta.UserID)
		c.Set("tokenID", meta.ID)
		c.Next()
	}
}

// SignToken 签发 access token（2 小时，含 jti 便于登出拉黑）
func SignToken(secret string, userID int64) (string, error) {
	now := time.Now()
	claims := jwt.MapClaims{
		"sub": userID,
		"exp": now.Add(2 * time.Hour).Unix(),
		"iat": now.Unix(),
		"jti": newJTI(),
		"typ": "access",
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString([]byte(secret))
}

// SignRefreshToken 签发 refresh token（30 天，含 jti）
func SignRefreshToken(secret string, userID int64) (string, error) {
	now := time.Now()
	claims := jwt.MapClaims{
		"sub": userID,
		"exp": now.Add(30 * 24 * time.Hour).Unix(),
		"iat": now.Unix(),
		"jti": newJTI(),
		"typ": "refresh",
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString([]byte(secret))
}

// SignAdminToken 签发管理员 token（2 小时，claims 带 role=admin）
func SignAdminToken(secret string, adminID int64) (string, error) {
	now := time.Now()
	claims := jwt.MapClaims{
		"sub":  adminID,
		"role": "admin",
		"exp":  now.Add(2 * time.Hour).Unix(),
		"iat":  now.Unix(),
		"jti":  newJTI(),
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString([]byte(secret))
}

// AdminAuth 验证管理后台 Bearer token：必须含 role=admin，注入 adminID
func AdminAuth(secret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		tokenStr := bearerToken(c)
		if tokenStr == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "缺少令牌"})
			return
		}

		token, err := jwt.Parse(tokenStr, func(t *jwt.Token) (interface{}, error) {
			if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, jwt.ErrSignatureInvalid
			}
			return []byte(secret), nil
		})
		if err != nil || !token.Valid {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "令牌无效或已过期"})
			return
		}

		claims, ok := token.Claims.(jwt.MapClaims)
		if !ok || claims["role"] != "admin" {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "无管理员权限"})
			return
		}
		adminID, ok := claims["sub"].(float64)
		if !ok {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "令牌缺少管理员ID"})
			return
		}
		c.Set("adminID", int64(adminID))
		c.Next()
	}
}
