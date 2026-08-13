package tokenstore

import (
	"context"
	"sync"
	"time"

	"github.com/redis/go-redis/v9"
)

const denyKeyPrefix = "auth:deny:"

// Denylist 将已登出/作废的 token id（jti 或哈希）标记为不可用，直到原过期时间。
type Denylist interface {
	Deny(ctx context.Context, id string, ttl time.Duration) error
	Denied(ctx context.Context, id string) (bool, error)
}

// Nop 无 Redis 时的空实现：登出不会使已签发 JWT 立即失效（见 README）。
type Nop struct{}

func (Nop) Deny(context.Context, string, time.Duration) error { return nil }
func (Nop) Denied(context.Context, string) (bool, error)      { return false, nil }

// RedisDenylist 用 Redis SET + TTL 存黑名单。
type RedisDenylist struct {
	rdb *redis.Client
}

func NewRedis(rdb *redis.Client) *RedisDenylist {
	if rdb == nil {
		return nil
	}
	return &RedisDenylist{rdb: rdb}
}

func (d *RedisDenylist) Deny(ctx context.Context, id string, ttl time.Duration) error {
	if d == nil || d.rdb == nil || id == "" {
		return nil
	}
	if ttl <= 0 {
		ttl = time.Minute
	}
	return d.rdb.Set(ctx, denyKeyPrefix+id, "1", ttl).Err()
}

func (d *RedisDenylist) Denied(ctx context.Context, id string) (bool, error) {
	if d == nil || d.rdb == nil || id == "" {
		return false, nil
	}
	n, err := d.rdb.Exists(ctx, denyKeyPrefix+id).Result()
	if err != nil {
		return false, err
	}
	return n > 0, nil
}

// Memory 进程内黑名单，仅用于单测。
type Memory struct {
	mu sync.Mutex
	m  map[string]time.Time
}

func NewMemory() *Memory {
	return &Memory{m: make(map[string]time.Time)}
}

func (d *Memory) Deny(_ context.Context, id string, ttl time.Duration) error {
	if id == "" {
		return nil
	}
	if ttl <= 0 {
		ttl = time.Minute
	}
	d.mu.Lock()
	d.m[id] = time.Now().Add(ttl)
	d.mu.Unlock()
	return nil
}

func (d *Memory) Denied(_ context.Context, id string) (bool, error) {
	d.mu.Lock()
	defer d.mu.Unlock()
	exp, ok := d.m[id]
	if !ok {
		return false, nil
	}
	if time.Now().After(exp) {
		delete(d.m, id)
		return false, nil
	}
	return true, nil
}
