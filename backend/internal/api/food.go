package api

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
)

// recognizeHandler 食物识别代理（M3 实现）
//
// 目标：接收 App 上传的照片 → 转发智谱 GLM / 百度识别 →
// 返回对齐 App 端 RecognizedFood 的结构化结果。
// 当前返回 501 明确占位，保证路由完整可调用。
func recognizeHandler(_ *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.JSON(http.StatusNotImplemented, gin.H{
			"error": "食物识别代理将在 M3 阶段接入（GLM/百度密钥只存服务器）",
		})
	}
}

// barcodeHandler 条形码查询（M3 实现）
func barcodeHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.JSON(http.StatusNotImplemented, gin.H{
			"error": "条码查询将在 M3 阶段接入",
		})
	}
}

// searchHandler 文本检索（M3 实现）
func searchHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.JSON(http.StatusNotImplemented, gin.H{
			"error": "文本检索将在 M3 阶段接入",
		})
	}
}

// feedbackHandler 用户纠错反馈沉淀（M3 实现）
func feedbackHandler(_ *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.JSON(http.StatusNotImplemented, gin.H{
			"error": "纠错反馈将在 M3 阶段接入",
		})
	}
}
