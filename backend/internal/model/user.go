package model

import (
	"encoding/json"
	"time"
)

// User 用户账号
type User struct {
	ID        int64     `json:"id"`
	Email     string    `json:"email"`
	Nickname  string    `json:"nickname"`
	PassHash  string    `json:"-"`
	AvatarURL string    `json:"avatarUrl,omitempty"`
	CreatedAt time.Time `json:"createdAt"`
}

// RegisterRequest 注册请求体
type RegisterRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=6"`
	Nickname string `json:"nickname" binding:"required,min=2,max=24"`
}

// LoginRequest 登录请求体
type LoginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required"`
}

// TokenPair access + refresh 令牌对
type TokenPair struct {
	AccessToken  string `json:"accessToken"`
	RefreshToken string `json:"refreshToken"`
	ExpiresIn    int64  `json:"expiresIn"` // 秒
}

// GameSnapshot 进度快照（对齐 App 端 GameState.toJson 的通用载体）
type GameSnapshot struct {
	UserID    int64           `json:"-"`
	StateJSON json.RawMessage `json:"state" binding:"required"`
	UpdatedAt time.Time       `json:"updatedAt"`
}
