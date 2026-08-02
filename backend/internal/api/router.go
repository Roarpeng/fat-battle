package api

import (
	"net/http"
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"

	"fatbattle/backend/internal/middleware"
)

// NewRouter 构建带基础中间件的路由引擎
func NewRouter(_ *pgxpool.Pool, _ string) *gin.Engine {
	r := gin.New()
	r.Use(gin.Logger(), gin.Recovery())
	r.Use(cors.New(cors.Config{
		AllowAllOrigins:  true,
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization"},
		AllowCredentials: true,
		MaxAge:           12 * time.Hour,
	}))
	return r
}

// RegisterRoutes 注册全部 API 路由
func RegisterRoutes(r *gin.Engine, pool *pgxpool.Pool, jwtSecret, adminJwtSecret string) {
	api := r.Group("/api/v1")
	{
		// 健康检查（docker compose healthcheck 依赖）
		api.GET("/healthz", func(c *gin.Context) {
			status := "ok"
			if pool == nil {
				status = "degraded"
			}
			c.JSON(http.StatusOK, gin.H{
				"status":  status,
				"service": "塑身工坊",
				"time":    time.Now().Format(time.RFC3339),
			})
		})

		// 账号管理（无鉴权）
		auth := api.Group("/auth")
		{
			auth.POST("/register", registerHandler(pool, jwtSecret))
			auth.POST("/login", loginHandler(pool, jwtSecret))
			auth.POST("/refresh", refreshHandler(pool, jwtSecret))
			auth.POST("/logout", logoutHandler())
		}

		// 鉴权保护的子模块
		protected := api.Group("", middleware.Auth(jwtSecret))
		{
			protected.GET("/user/me", meHandler(pool))
			protected.DELETE("/user", deleteAccountHandler(pool))

			// 食物识别代理（GLM 转发，密钥只留服务器）
			food := protected.Group("/food")
			{
				food.POST("/recognize", recognizeHandler(pool))
				food.POST("/barcode", barcodeHandler())
				food.POST("/search", searchHandler(pool))
				food.POST("/feedback", feedbackHandler(pool))
			}

			// 进度同步（M4 实现快照与增量流水）
			progress := protected.Group("/progress")
			{
				progress.POST("/snapshot", snapshotHandler(pool))
				progress.GET("/snapshot", getSnapshotHandler(pool))
				progress.POST("/events", eventsHandler())
				progress.GET("/events", getEventsHandler())
				progress.GET("/summary", summaryHandler())
			}
		}
	}

	// 管理后台：单页入口（Go embed）
	r.GET("/admin", adminIndexHandler())
	r.GET("/admin/", adminIndexHandler())

	// 管理 API（/api/admin，独立 JWT secret）
	admin := r.Group("/api/admin")
	{
		admin.POST("/login", adminLoginHandler(pool, adminJwtSecret))

		adminAuth := admin.Group("", middleware.AdminAuth(adminJwtSecret))
		{
			adminAuth.GET("/users", adminUsersHandler(pool))
			adminAuth.POST("/users/:id/disable", adminUserDisableHandler(pool, true))
			adminAuth.POST("/users/:id/enable", adminUserDisableHandler(pool, false))
			adminAuth.POST("/users/:id/reset-password", adminUserResetPasswordHandler(pool))

			adminAuth.GET("/llm", adminLLMListHandler(pool))
			adminAuth.POST("/llm", adminLLMCreateHandler(pool))
			adminAuth.PUT("/llm/:id", adminLLMUpdateHandler(pool))
			adminAuth.DELETE("/llm/:id", adminLLMDeleteHandler(pool))
			adminAuth.POST("/llm/:id/test", adminLLMTestHandler(pool))

			adminAuth.GET("/stats", adminStatsHandler(pool))
		}
	}
}
