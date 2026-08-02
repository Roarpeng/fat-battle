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

	"fatbattle/backend/internal/api"
	"fatbattle/backend/internal/repo"
)

func main() {
	// 环境变量（docker-compose 注入，默认值适配本地开发）
	port := envOr("PORT", "8080")
	dsn := envOr("DATABASE_URL",
		"postgres://fatbattle:fatbattle@localhost:5432/fatbattle?sslmode=disable")
	jwtSecret := envOr("JWT_SECRET", "dev-secret-change-me")

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
	}
	defer func() {
		if pool != nil {
			pool.Close()
		}
	}()

	r := api.NewRouter(pool, jwtSecret)
	api.RegisterRoutes(r, pool, jwtSecret)

	srv := &http.Server{
		Addr:              ":" + port,
		Handler:           r,
		ReadHeaderTimeout: 10 * time.Second,
	}

	go func() {
		log.Printf("塑身工坊后端启动: http://0.0.0.0:%s", port)
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
