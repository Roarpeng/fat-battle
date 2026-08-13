package repo

import (
	"context"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
)

// ConnectRedis 解析 REDIS_URL 并 ping。失败时由调用方降级为无黑名单。
func ConnectRedis(ctx context.Context, url string) (*redis.Client, error) {
	if url == "" {
		return nil, fmt.Errorf("REDIS_URL 为空")
	}
	opt, err := redis.ParseURL(url)
	if err != nil {
		return nil, fmt.Errorf("解析 REDIS_URL: %w", err)
	}
	rdb := redis.NewClient(opt)
	pingCtx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	if err := rdb.Ping(pingCtx).Err(); err != nil {
		_ = rdb.Close()
		return nil, err
	}
	return rdb, nil
}
