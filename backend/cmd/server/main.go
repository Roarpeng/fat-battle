// 塑身工坊后端入口
//
// 服务：账号管理 / 食物识别代理 / 进度记录云同步
// 部署：docker compose up -d（一键启动，见 /backend/docker-compose.yml）
package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"

	backend "fatbattle/backend"
	"fatbattle/backend/internal/api"
	"fatbattle/backend/internal/repo"
	"fatbattle/backend/internal/tokenstore"
)

func main() {
	// 环境变量（docker-compose 注入，默认值适配本地开发）
	port := envOr("PORT", "8080")
	dsn := envOr("DATABASE_URL",
		"postgres://fatbattle:fatbattle@localhost:5432/fatbattle?sslmode=disable")
	jwtSecret := envOr("JWT_SECRET", "dev-secret-change-me")
	adminJwtSecret := envOr("ADMIN_JWT_SECRET", "admin-secret-change-me")
	adminUser := envOr("ADMIN_USER", "admin")
	adminPass := envOr("ADMIN_PASS", "admin123456")
	redisURL := envOr("REDIS_URL", "redis://localhost:6379/0")

	if os.Getenv("GIN_MODE") == "release" {
		gin.SetMode(gin.ReleaseMode)
	}

	// 数据库连接（失败时降级为「内存模式」，保证容器能起、健康检查能过）
	ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
	defer cancel()
	pool, err := repo.Connect(ctx, dsn)
	if err != nil {
		log.Printf("[warn] 数据库未就绪，降级内存模式: %v", err)
		pool = nil
	} else {
		log.Println("[ok] PostgreSQL 已连接")
		// 执行迁移（embed 读取 migrations 按文件名顺序，幂等；兼容老库）
		if err := backend.RunMigrations(ctx, pool); err != nil {
			log.Printf("[warn] 迁移执行失败（继续启动）: %v", err)
		} else if err := backend.SeedAdmin(ctx, pool, adminUser, adminPass); err != nil {
			log.Printf("[warn] 种子管理员创建失败: %v", err)
		}
	}
	defer func() {
		if pool != nil {
			pool.Close()
		}
	}()

	var dl tokenstore.Denylist = tokenstore.Nop{}
	rdb, err := repo.ConnectRedis(context.Background(), redisURL)
	if err != nil {
		log.Printf("[warn] Redis 未就绪，登出黑名单不可用（token 仅客户端丢弃）: %v", err)
	} else {
		log.Println("[ok] Redis 已连接（登出黑名单启用）")
		dl = tokenstore.NewRedis(rdb)
		defer rdb.Close()
	}

	r := api.NewRouter(pool, jwtSecret)
	api.RegisterRoutes(r, pool, jwtSecret, adminJwtSecret, dl)

	srv := &http.Server{
		Addr:              ":" + port,
		Handler:           r,
		ReadHeaderTimeout: 10 * time.Second,
	}

	go func() {
		log.Printf("塑身工坊后端启动: http://0.0.0.0:%s  管理后台 /admin", port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("[fatal] 服务启动失败: %v", err)
		}
	}()

	// 优雅退出
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("收到退出信号，正在关闭...")
	shutdownCtx, cancelShutdown := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancelShutdown()
	_ = srv.Shutdown(shutdownCtx)
	log.Println("已退出")
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
