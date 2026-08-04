package middleware

import (
	"net/http"
	"strconv"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

// 简单固定窗口限流器（单实例部署够用；多实例请换 Redis）
type rateBucket struct {
	count       int
	windowStart time.Time
}

// RateLimit 按客户端维度限流：已登录用户按 userID，否则按 IP。
// 超限返回 429。
func RateLimit(limit int, window time.Duration) gin.HandlerFunc {
	var mu sync.Mutex
	buckets := make(map[string]*rateBucket)

	// 后台定期清理过期桶，防止内存无限增长
	go func() {
		for range time.Tick(window) {
			mu.Lock()
			now := time.Now()
			for k, b := range buckets {
				if now.Sub(b.windowStart) > window*2 {
					delete(buckets, k)
				}
			}
			mu.Unlock()
		}
	}()

	return func(c *gin.Context) {
		key := "ip:" + c.ClientIP()
		if id, exists := c.Get("userID"); exists {
			key = "uid:" + strconv.FormatInt(id.(int64), 10)
		}

		now := time.Now()
		mu.Lock()
		b, ok := buckets[key]
		if !ok || now.Sub(b.windowStart) >= window {
			buckets[key] = &rateBucket{count: 1, windowStart: now}
			mu.Unlock()
			c.Next()
			return
		}
		b.count++
		over := b.count > limit
		mu.Unlock()

		if over {
			c.Header("Retry-After", strconv.Itoa(int(window.Seconds())))
			c.AbortWithStatusJSON(http.StatusTooManyRequests,
				gin.H{"error": "请求过于频繁，请稍后再试"})
			return
		}
		c.Next()
	}
}
