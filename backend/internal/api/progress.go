package api

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
)

// snapshotHandler 进度快照上传（M4 实现）
//
// 目标：接收 App 端 GameState.toJson() 全量快照，
// upsert 到 user_progress 表，作为换机/重装恢复载体。
func snapshotHandler(_ *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.JSON(http.StatusNotImplemented, gin.H{
			"error": "进度快照将在 M4 阶段实现",
		})
	}
}

// getSnapshotHandler 拉取最新进度快照（M4 实现）
func getSnapshotHandler(_ *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.JSON(http.StatusNotImplemented, gin.H{
			"error": "进度快照将在 M4 阶段实现",
		})
	}
}

// eventsHandler 行为流水上传（M4 实现）
func eventsHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.JSON(http.StatusNotImplemented, gin.H{
			"error": "行为流水将在 M4 阶段实现",
		})
	}
}

// getEventsHandler 增量拉取（M4 实现）
func getEventsHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.JSON(http.StatusNotImplemented, gin.H{
			"error": "行为流水将在 M4 阶段实现",
		})
	}
}

// summaryHandler 周报/趋势（M4 实现）
func summaryHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.JSON(http.StatusNotImplemented, gin.H{
			"error": "统计摘要将在 M4 阶段实现",
		})
	}
}
