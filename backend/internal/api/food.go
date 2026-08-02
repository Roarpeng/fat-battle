package api

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// 智谱 GLM 代理常量（对齐 App 端 GlmFoodService 的契约）
const (
	glmProvider     = "zhipu" // 当前支持的 provider
	glmSystemPrompt = "你是专业的食物识别和营养分析专家。请识别图片中的食物，返回结构化 JSON 结果。\n【重要】只输出 JSON，不要有任何其他文字、解释或代码块标记。\n【输出格式】\n{\"items\":[{\"name\":\"食物名称\",\"calorie\":每100克卡路里数值,\"confidence\":置信度0-1,\"category\":\"食物类别\",\"description\":\"简短描述\"}]}\n【要求】name用中文；calorie为每100g千卡；置信度低于0.3不要返回；最多识别清晰可见的食物。"
)

// llmConfig 数据库 llm_configs 行的镜像
type llmConfig struct {
	ID          int64  `json:"id"`
	Name        string `json:"name"`
	Provider    string `json:"provider"`
	BaseURL     string `json:"baseUrl"`
	APIKey      string `json:"apiKey"`
	VisionModel string `json:"visionModel"`
	TextModel   string `json:"textModel"`
	Enabled     bool   `json:"enabled"`
	Priority    int    `json:"priority"`
	Remark      string `json:"remark"`
}

// pickLLMConfig 取第一条 enabled=true 的 zhipu 配置（按 priority 升序）
func pickLLMConfig(ctx context.Context, pool *pgxpool.Pool) (*llmConfig, error) {
	rows, err := pool.Query(ctx, `SELECT id, name, provider, base_url, api_key,
		vision_model, text_model, enabled, priority, COALESCE(remark, '')
		FROM llm_configs WHERE enabled = true ORDER BY priority ASC, id ASC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	for rows.Next() {
		var cfg llmConfig
		if err := rows.Scan(&cfg.ID, &cfg.Name, &cfg.Provider, &cfg.BaseURL, &cfg.APIKey,
			&cfg.VisionModel, &cfg.TextModel, &cfg.Enabled, &cfg.Priority, &cfg.Remark); err != nil {
			return nil, err
		}
		if cfg.Provider == glmProvider {
			return &cfg, nil
		}
	}
	if rows.Err() != nil {
		return nil, rows.Err()
	}
	return nil, pgx.ErrNoRows // 无可用 zhipu 配置
}

// chat 调用 GLM 兼容的 chat/completions 接口，返回 choices[0].message.content
func (cfg *llmConfig) chat(ctx context.Context, model string, messages []gin.H) (string, error) {
	url := strings.TrimRight(cfg.BaseURL, "/") + "/api/paas/v4/chat/completions"
	body, err := json.Marshal(gin.H{
		"model":      model,
		"messages":   messages,
		"temperature": 0.1,
		"max_tokens": 2048,
	})
	if err != nil {
		return "", fmt.Errorf("构造请求体: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+cfg.APIKey)

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return "", fmt.Errorf("调用 GLM 失败: %w", err)
	}
	defer resp.Body.Close()
	respBody, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("GLM HTTP %d: %s", resp.StatusCode, truncate(string(respBody), 200))
	}

	var result struct {
		Choices []struct {
			Message struct {
				Content json.RawMessage `json:"content"`
			} `json:"message"`
		} `json:"choices"`
		Error *struct {
			Message string `json:"message"`
		} `json:"error"`
	}
	if err := json.Unmarshal(respBody, &result); err != nil {
		return "", fmt.Errorf("解析 GLM 响应: %w", err)
	}
	if result.Error != nil && result.Error.Message != "" {
		return "", fmt.Errorf("GLM 错误: %s", result.Error.Message)
	}
	if len(result.Choices) == 0 {
		return "", fmt.Errorf("GLM 未返回结果")
	}

	raw := result.Choices[0].Message.Content
	// content 可能是纯字符串，也可能是多段数组（部分视觉模型）
	if len(raw) > 0 && raw[0] == '[' {
		var parts []struct {
			Text string `json:"text"`
		}
		if err := json.Unmarshal(raw, &parts); err == nil {
			var sb strings.Builder
			for _, p := range parts {
				sb.WriteString(p.Text)
			}
			if sb.Len() > 0 {
				return sb.String(), nil
			}
		}
	}
	var s string
	if err := json.Unmarshal(raw, &s); err != nil {
		return "", fmt.Errorf("解析 GLM content: %w", err)
	}
	return s, nil
}

// extractJSON 从 LLM 输出中提取 JSON 对象（兼容 markdown 代码块包裹）
func extractJSON(content string) string {
	trimmed := strings.TrimSpace(content)
	if trimmed == "" {
		return ""
	}
	// 去掉 ```json ... ``` 围栏
	if idx := strings.Index(trimmed, "```"); idx >= 0 {
		rest := trimmed[idx+3:]
		rest = strings.TrimPrefix(rest, "json")
		if end := strings.Index(rest, "```"); end >= 0 {
			trimmed = strings.TrimSpace(rest[:end])
		}
	}
	// 取第一个 { 到最后一个 }
	start := strings.Index(trimmed, "{")
	end := strings.LastIndex(trimmed, "}")
	if start < 0 || end <= start {
		return ""
	}
	return trimmed[start : end+1]
}

// numToFloat 兼容模型返回的数字或字符串数值
func numToFloat(v interface{}) float64 {
	switch t := v.(type) {
	case float64:
		return t
	case json.Number:
		f, _ := t.Float64()
		return f
	case string:
		f, err := strconv.ParseFloat(strings.TrimSpace(t), 64)
		if err != nil {
			return 0
		}
		return f
	case int:
		return float64(t)
	case bool:
		if t {
			return 1
		}
	}
	return 0
}

// parseFoodItems 解析 LLM 的 items 并规范化（has_calorie = calorie > 0）
func parseFoodItems(content string, topNum int) []gin.H {
	jsonStr := extractJSON(content)
	if jsonStr == "" {
		return nil
	}
	var parsed struct {
		Items []struct {
			Name        string      `json:"name"`
			Calorie     interface{} `json:"calorie"`
			Confidence  interface{} `json:"confidence"`
			Category    string      `json:"category"`
			Description string      `json:"description"`
		} `json:"items"`
	}
	if err := json.Unmarshal([]byte(jsonStr), &parsed); err != nil {
		log.Printf("[food] 解析 LLM JSON 失败: %v，原文: %s", err, truncate(jsonStr, 200))
		return nil
	}

	items := make([]gin.H, 0, len(parsed.Items))
	for _, it := range parsed.Items {
		if strings.TrimSpace(it.Name) == "" {
			continue
		}
		calorie := numToFloat(it.Calorie)
		confidence := numToFloat(it.Confidence)
		if confidence > 0 && confidence < 0.3 {
			continue // 低于 0.3 不返回
		}
		if confidence == 0 {
			confidence = 0.7 // 模型偶发省略置信度：给默认值
		}
		items = append(items, gin.H{
			"name":        it.Name,
			"calorie":     calorie,
			"confidence":  confidence,
			"has_calorie": calorie > 0,
			"category":    it.Category,
			"description": it.Description,
		})
		if len(items) >= topNum {
			break
		}
	}
	return items
}

func foodError(c *gin.Context, code int, msg string) {
	c.Header("X-Provider", glmProvider)
	c.JSON(code, gin.H{"success": false, "error": msg})
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n] + "..."
}

// recognizeHandler 食物识别代理：App 上传 base64 图片 → 智谱 GLM 视觉模型 → 结构化结果
//
// 请求: {"image": "<base64>", "topNum": 5, "thinking": false}
// 响应: {"success": true, "items": [...]}
func recognizeHandler(pool *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("X-Provider", glmProvider)
		if pool == nil {
			foodError(c, http.StatusServiceUnavailable, "数据库未就绪，请检查 Docker 服务")
			return
		}
		var req struct {
			Image    string `json:"image" binding:"required"`
			TopNum   int    `json:"topNum"`
			Thinking bool   `json:"thinking"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			foodError(c, http.StatusBadRequest, "参数错误: "+err.Error())
			return
		}
		if req.Image == "" {
			foodError(c, http.StatusBadRequest, "image 不能为空")
			return
		}
		if req.TopNum <= 0 {
			req.TopNum = 5
		}
		if req.TopNum > 20 {
			req.TopNum = 20
		}

		cfg, err := pickLLMConfig(c.Request.Context(), pool)
		if err != nil {
			if err == pgx.ErrNoRows {
				foodError(c, http.StatusServiceUnavailable, "未配置可用的 LLM 服务，请在管理后台配置")
				return
			}
			foodError(c, http.StatusInternalServerError, "读取 LLM 配置失败")
			return
		}

		model := cfg.VisionModel
		if model == "" {
			model = "glm-4.6v-flash"
		}
		userContent := []gin.H{
			{"type": "image_url", "image_url": gin.H{"url": "data:image/jpeg;base64," + req.Image}},
			{"type": "text", "text": fmt.Sprintf("请识别这张图片中的食物，返回最多 %d 个结果。只输出 JSON。", req.TopNum)},
		}
		content, err := cfg.chat(c.Request.Context(), model, []gin.H{
			{"role": "system", "content": glmSystemPrompt},
			{"role": "user", "content": userContent},
		})
		if err != nil {
			log.Printf("[food] 识别调用失败: %v", err)
			foodError(c, http.StatusBadGateway, "食物识别服务调用失败: "+err.Error())
			return
		}

		items := parseFoodItems(content, req.TopNum)
		if items == nil {
			foodError(c, http.StatusBadGateway, "识别结果解析失败，请稍后重试")
			return
		}
		c.JSON(http.StatusOK, gin.H{"success": true, "items": items})
	}
}

// searchHandler 食物文本检索：LLM 按关键词返回最匹配的食物与卡路里
//
// 请求: {"query": "...", "topNum": 3}
// 响应: {"success": true, "items": [...]}
func searchHandler(pool *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("X-Provider", glmProvider)
		if pool == nil {
			foodError(c, http.StatusServiceUnavailable, "数据库未就绪，请检查 Docker 服务")
			return
		}
		var req struct {
			Query  string `json:"query" binding:"required"`
			TopNum int    `json:"topNum"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			foodError(c, http.StatusBadRequest, "参数错误: "+err.Error())
			return
		}
		if strings.TrimSpace(req.Query) == "" {
			foodError(c, http.StatusBadRequest, "query 不能为空")
			return
		}
		if req.TopNum <= 0 {
			req.TopNum = 3
		}
		if req.TopNum > 20 {
			req.TopNum = 20
		}

		cfg, err := pickLLMConfig(c.Request.Context(), pool)
		if err != nil {
			if err == pgx.ErrNoRows {
				foodError(c, http.StatusServiceUnavailable, "未配置可用的 LLM 服务，请在管理后台配置")
				return
			}
			foodError(c, http.StatusInternalServerError, "读取 LLM 配置失败")
			return
		}

		model := cfg.TextModel
		if model == "" {
			model = "glm-4-flash"
		}
		// 与 App 端 GlmFoodService._searchDirect 的提示词保持一致（含常见食物卡路里参考表）
		systemPrompt := fmt.Sprintf(`你是一个食物搜索引擎。用户输入关键词，你必须搜索并返回最匹配的食物。

规则：
1. 只输出JSON，禁止输出任何其他文字、解释、markdown标记
2. 将用户输入视为食物搜索关键词
3. 如果输入有错别字（如"酸菜睡觉"可能是"酸菜水饺"），自动纠正并搜索
4. 返回与搜索词最相关的食物，不要返回无关食物
5. 如果实在无法匹配任何食物，返回 {"items": []}

JSON格式：
{"items":[{"name":"食物中文名","calorie":每100克卡路里数值,"confidence":0到1的置信度,"category":"主食/蔬菜/水果/肉类/蛋奶/零食/饮品/快餐/其他","description":"简短描述"}]}

常见食物卡路里参考（每100g）：
米饭116、馒头221、面条109、水饺240、包子227、面包312、白菜17、西兰花36、番茄20、黄瓜16、土豆77、苹果52、香蕉89、橙子47、西瓜30、猪肉143、牛肉125、鸡肉165、鱼肉113、鸡蛋143、牛奶54、酸奶72、豆腐70、薯片536、巧克力546、饼干433、可乐43、果汁54、奶茶80、汉堡295、薯条298、披萨266、炸鸡240、方便面450

最多返回%d个结果，置信度低于0.3的不返回。`, req.TopNum)

		content, err := cfg.chat(c.Request.Context(), model, []gin.H{
			{"role": "system", "content": systemPrompt},
			{"role": "user", "content": "搜索：" + req.Query},
		})
		if err != nil {
			log.Printf("[food] 搜索调用失败: %v", err)
			foodError(c, http.StatusBadGateway, "食物搜索服务调用失败: "+err.Error())
			return
		}

		items := parseFoodItems(content, req.TopNum)
		if items == nil {
			foodError(c, http.StatusBadGateway, "搜索结果解析失败，请稍后重试")
			return
		}
		c.JSON(http.StatusOK, gin.H{"success": true, "items": items})
	}
}

// barcodeHandler 条形码查询（后续接入条码库）
func barcodeHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.JSON(http.StatusNotImplemented, gin.H{
			"error": "条码查询将在后续接入",
		})
	}
}

// feedbackHandler 用户纠错反馈落库（供识别质量回填优化）
func feedbackHandler(pool *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		if pool == nil {
			jsonError(c, http.StatusServiceUnavailable, "数据库未就绪")
			return
		}
		var req struct {
			ImageURL string          `json:"image_url"`
			OCRResult json.RawMessage `json:"ocr_result"`
			UserCal  *int            `json:"user_cal"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			jsonError(c, http.StatusBadRequest, "参数错误: "+err.Error())
			return
		}
		ocr := json.RawMessage("null")
		if len(req.OCRResult) > 0 {
			ocr = req.OCRResult
		}
		userID := c.GetInt64("userID")
		_, err := pool.Exec(c.Request.Context(),
			`INSERT INTO food_feedback (user_id, image_url, ocr_result, user_cal, status)
			 VALUES ($1, NULLIF($2, ''), $3, $4, 'pending')`,
			userID, req.ImageURL, ocr, req.UserCal)
		if err != nil {
			jsonError(c, http.StatusInternalServerError, "反馈保存失败: "+err.Error())
			return
		}
		c.JSON(http.StatusOK, gin.H{"ok": true})
	}
}
