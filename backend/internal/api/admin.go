package api

import (
	"errors"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"

	"fatbattle/backend/internal/adminui"
	"fatbattle/backend/internal/middleware"
)

// ---------- 登录 ----------

// adminLoginHandler 管理员登录：bcrypt 校验，签发带 role=admin 的 token
func adminLoginHandler(pool *pgxpool.Pool, adminJwtSecret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		if pool == nil {
			jsonError(c, http.StatusServiceUnavailable, "数据库未就绪")
			return
		}
		var req struct {
			Username string `json:"username" binding:"required"`
			Password string `json:"password" binding:"required"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			jsonError(c, http.StatusBadRequest, "参数错误: "+err.Error())
			return
		}
		var id int64
		var passHash, role, username string
		err := pool.QueryRow(c.Request.Context(),
			`SELECT id, username, pass_hash, role FROM admin_users WHERE username = $1`,
			req.Username,
		).Scan(&id, &username, &passHash, &role)
		if errors.Is(err, pgx.ErrNoRows) {
			jsonError(c, http.StatusUnauthorized, "账号或密码错误")
			return
		}
		if err != nil {
			jsonError(c, http.StatusInternalServerError, "查询失败")
			return
		}
		if bcrypt.CompareHashAndPassword([]byte(passHash), []byte(req.Password)) != nil {
			jsonError(c, http.StatusUnauthorized, "账号或密码错误")
			return
		}
		token, err := middleware.SignAdminToken(adminJwtSecret, id)
		if err != nil {
			jsonError(c, http.StatusInternalServerError, "签发令牌失败")
			return
		}
		c.JSON(http.StatusOK, gin.H{"token": token, "username": username, "role": role})
	}
}

// ---------- 用户管理 ----------

// adminUsersHandler 用户列表（q 模糊匹配 email/nickname，分页）
func adminUsersHandler(pool *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		if pool == nil {
			jsonError(c, http.StatusServiceUnavailable, "数据库未就绪")
			return
		}
		q := strings.TrimSpace(c.Query("q"))
		page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
		pageSize, _ := strconv.Atoi(c.DefaultQuery("pageSize", "20"))
		if page < 1 {
			page = 1
		}
		if pageSize < 1 || pageSize > 100 {
			pageSize = 20
		}

		where := `WHERE deleted_at IS NULL`
		args := []interface{}{}
		if q != "" {
			args = append(args, "%"+q+"%")
			where += ` AND (email ILIKE $1 OR nickname ILIKE $1)`
		}
		args = append(args, pageSize, (page-1)*pageSize)

		var total int
		_ = pool.QueryRow(c.Request.Context(),
			`SELECT COUNT(*) FROM users `+where, args[:len(args)-2]...).Scan(&total)

		rows, err := pool.Query(c.Request.Context(),
			`SELECT id, email, nickname, COALESCE(avatar_url, ''), created_at, is_disabled
			 FROM users `+where+` ORDER BY id DESC LIMIT $`+strconv.Itoa(len(args)-1)+` OFFSET $`+strconv.Itoa(len(args)),
			args...)
		if err != nil {
			jsonError(c, http.StatusInternalServerError, "查询失败: "+err.Error())
			return
		}
		defer rows.Close()

		items := make([]gin.H, 0, pageSize)
		for rows.Next() {
			var id int64
			var email, nickname, avatar string
			var createdAt time.Time
			var isDisabled bool
			if err := rows.Scan(&id, &email, &nickname, &avatar, &createdAt, &isDisabled); err != nil {
				jsonError(c, http.StatusInternalServerError, "查询失败: "+err.Error())
				return
			}
			items = append(items, gin.H{
				"id":         id,
				"email":      email,
				"nickname":   nickname,
				"createdAt":  createdAt,
				"isDisabled": isDisabled,
			})
		}
		c.JSON(http.StatusOK, gin.H{"total": total, "items": items})
	}
}

// adminUserDisableHandler 禁用/启用用户
func adminUserDisableHandler(pool *pgxpool.Pool, disable bool) gin.HandlerFunc {
	return func(c *gin.Context) {
		if pool == nil {
			jsonError(c, http.StatusServiceUnavailable, "数据库未就绪")
			return
		}
		id, err := strconv.ParseInt(c.Param("id"), 10, 64)
		if err != nil {
			jsonError(c, http.StatusBadRequest, "用户 ID 无效")
			return
		}
		_, err = pool.Exec(c.Request.Context(),
			`UPDATE users SET is_disabled = $1 WHERE id = $2 AND deleted_at IS NULL`,
			disable, id)
		if err != nil {
			jsonError(c, http.StatusInternalServerError, "操作失败: "+err.Error())
			return
		}
		c.JSON(http.StatusOK, gin.H{"ok": true, "id": id, "disabled": disable})
	}
}

// adminUserResetPasswordHandler 重置用户密码
func adminUserResetPasswordHandler(pool *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		if pool == nil {
			jsonError(c, http.StatusServiceUnavailable, "数据库未就绪")
			return
		}
		id, err := strconv.ParseInt(c.Param("id"), 10, 64)
		if err != nil {
			jsonError(c, http.StatusBadRequest, "用户 ID 无效")
			return
		}
		var req struct {
			Password string `json:"password" binding:"required,min=6"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			jsonError(c, http.StatusBadRequest, "密码至少 6 位")
			return
		}
		hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), 10)
		if err != nil {
			jsonError(c, http.StatusInternalServerError, "密码加密失败")
			return
		}
		_, err = pool.Exec(c.Request.Context(),
			`UPDATE users SET pass_hash = $1 WHERE id = $2 AND deleted_at IS NULL`,
			string(hash), id)
		if err != nil {
			jsonError(c, http.StatusInternalServerError, "重置失败: "+err.Error())
			return
		}
		c.JSON(http.StatusOK, gin.H{"ok": true, "id": id})
	}
}

// ---------- LLM 配置管理 ----------

// maskAPIKey 脱敏 api_key（列表展示用；编辑时不回传明文）
func maskAPIKey(key string) string {
	if key == "" {
		return ""
	}
	if len(key) <= 8 {
		return "****"
	}
	return key[:4] + "****" + key[len(key)-4:]
}

// scanLLMConfigs 查 llm_configs（id=0 表示全量，否则单条）
func scanLLMConfigs(c *gin.Context, pool *pgxpool.Pool, id int64) ([]llmConfig, error) {
	query := `SELECT id, name, provider, base_url, api_key, vision_model, text_model,
		enabled, priority, COALESCE(remark, '') FROM llm_configs`
	args := []interface{}{}
	if id > 0 {
		query += ` WHERE id = $1`
		args = append(args, id)
	}
	query += ` ORDER BY priority ASC, id ASC`
	rows, err := pool.Query(c.Request.Context(), query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	cfgs := make([]llmConfig, 0, 8)
	for rows.Next() {
		var cfg llmConfig
		if err := rows.Scan(&cfg.ID, &cfg.Name, &cfg.Provider, &cfg.BaseURL, &cfg.APIKey,
			&cfg.VisionModel, &cfg.TextModel, &cfg.Enabled, &cfg.Priority, &cfg.Remark); err != nil {
			return nil, err
		}
		cfgs = append(cfgs, cfg)
	}
	return cfgs, rows.Err()
}

func adminLLMListHandler(pool *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		if pool == nil {
			jsonError(c, http.StatusServiceUnavailable, "数据库未就绪")
			return
		}
		cfgs, err := scanLLMConfigs(c, pool, 0)
		if err != nil {
			jsonError(c, http.StatusInternalServerError, "查询失败: "+err.Error())
			return
		}
		items := make([]gin.H, 0, len(cfgs))
		for _, cfg := range cfgs {
			items = append(items, gin.H{
				"id":          cfg.ID,
				"name":        cfg.Name,
				"provider":    cfg.Provider,
				"baseUrl":     cfg.BaseURL,
				"apiKey":      maskAPIKey(cfg.APIKey),
				"visionModel": cfg.VisionModel,
				"textModel":   cfg.TextModel,
				"enabled":     cfg.Enabled,
				"priority":    cfg.Priority,
				"remark":      cfg.Remark,
			})
		}
		c.JSON(http.StatusOK, gin.H{"items": items})
	}
}

func adminLLMCreateHandler(pool *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		if pool == nil {
			jsonError(c, http.StatusServiceUnavailable, "数据库未就绪")
			return
		}
		var req struct {
			Name        string `json:"name" binding:"required"`
			Provider    string `json:"provider"`
			BaseURL     string `json:"baseUrl"`
			APIKey      string `json:"apiKey" binding:"required"`
			VisionModel string `json:"visionModel"`
			TextModel   string `json:"textModel"`
			Enabled     *bool  `json:"enabled"`
			Priority    *int   `json:"priority"`
			Remark      string `json:"remark"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			jsonError(c, http.StatusBadRequest, "参数错误: "+err.Error())
			return
		}
		enabled := true
		if req.Enabled != nil {
			enabled = *req.Enabled
		}
		priority := 0
		if req.Priority != nil {
			priority = *req.Priority
		}
		var id int64
		err := pool.QueryRow(c.Request.Context(),
			`INSERT INTO llm_configs (name, provider, base_url, api_key, vision_model, text_model, enabled, priority, remark)
			 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING id`,
			req.Name, def(req.Provider, "zhipu"), def(req.BaseURL, "https://open.bigmodel.cn"),
			req.APIKey, def(req.VisionModel, "glm-4.6v-flash"), def(req.TextModel, "glm-4-flash"),
			enabled, priority, req.Remark,
		).Scan(&id)
		if err != nil {
			jsonError(c, http.StatusInternalServerError, "创建失败: "+err.Error())
			return
		}
		c.JSON(http.StatusOK, gin.H{"ok": true, "id": id})
	}
}

func adminLLMUpdateHandler(pool *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		if pool == nil {
			jsonError(c, http.StatusServiceUnavailable, "数据库未就绪")
			return
		}
		id, err := strconv.ParseInt(c.Param("id"), 10, 64)
		if err != nil {
			jsonError(c, http.StatusBadRequest, "配置 ID 无效")
			return
		}
		var req struct {
			Name        string `json:"name"`
			Provider    string `json:"provider"`
			BaseURL     string `json:"baseUrl"`
			APIKey      string `json:"apiKey"` // 空或脱敏值 = 不修改
			VisionModel string `json:"visionModel"`
			TextModel   string `json:"textModel"`
			Enabled     *bool  `json:"enabled"`
			Priority    *int   `json:"priority"`
			Remark      *string `json:"remark"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			jsonError(c, http.StatusBadRequest, "参数错误: "+err.Error())
			return
		}
		set := []string{}
		args := []interface{}{}
		add := func(col string, v interface{}) {
			set = append(set, col+" = $"+strconv.Itoa(len(args)+1))
			args = append(args, v)
		}
		if req.Name != "" {
			add("name", req.Name)
		}
		if req.Provider != "" {
			add("provider", req.Provider)
		}
		if req.BaseURL != "" {
			add("base_url", req.BaseURL)
		}
		// apiKey 空或包含 *（脱敏值）则视为不修改
		if req.APIKey != "" && !strings.Contains(req.APIKey, "*") {
			add("api_key", req.APIKey)
		}
		if req.VisionModel != "" {
			add("vision_model", req.VisionModel)
		}
		if req.TextModel != "" {
			add("text_model", req.TextModel)
		}
		if req.Enabled != nil {
			add("enabled", *req.Enabled)
		}
		if req.Priority != nil {
			add("priority", *req.Priority)
		}
		if req.Remark != nil {
			add("remark", *req.Remark)
		}
		if len(set) == 0 {
			jsonError(c, http.StatusBadRequest, "没有可更新的字段")
			return
		}
		args = append(args, id)
		_, err = pool.Exec(c.Request.Context(),
			`UPDATE llm_configs SET `+strings.Join(set, ", ")+` WHERE id = $`+strconv.Itoa(len(args)),
			args...)
		if err != nil {
			jsonError(c, http.StatusInternalServerError, "更新失败: "+err.Error())
			return
		}
		c.JSON(http.StatusOK, gin.H{"ok": true, "id": id})
	}
}

func adminLLMDeleteHandler(pool *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		if pool == nil {
			jsonError(c, http.StatusServiceUnavailable, "数据库未就绪")
			return
		}
		id, err := strconv.ParseInt(c.Param("id"), 10, 64)
		if err != nil {
			jsonError(c, http.StatusBadRequest, "配置 ID 无效")
			return
		}
		if _, err := pool.Exec(c.Request.Context(), `DELETE FROM llm_configs WHERE id = $1`, id); err != nil {
			jsonError(c, http.StatusInternalServerError, "删除失败: "+err.Error())
			return
		}
		c.JSON(http.StatusOK, gin.H{"ok": true, "id": id})
	}
}

// adminLLMTestHandler 连通性测试：用该配置的 text_model 发一次最小请求
func adminLLMTestHandler(pool *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		if pool == nil {
			jsonError(c, http.StatusServiceUnavailable, "数据库未就绪")
			return
		}
		id, err := strconv.ParseInt(c.Param("id"), 10, 64)
		if err != nil {
			jsonError(c, http.StatusBadRequest, "配置 ID 无效")
			return
		}
		cfgs, err := scanLLMConfigs(c, pool, id)
		if err != nil {
			jsonError(c, http.StatusInternalServerError, "查询失败")
			return
		}
		if len(cfgs) == 0 {
			jsonError(c, http.StatusNotFound, "配置不存在")
			return
		}
		cfg := cfgs[0]
		if cfg.APIKey == "" {
			c.JSON(http.StatusOK, gin.H{"ok": false, "error": "该配置未填写 api_key"})
			return
		}
		model := cfg.TextModel
		if model == "" {
			model = defaultTextModel(cfg.Provider)
		}
		start := time.Now()
		content, err := cfg.chat(c.Request.Context(), model, []gin.H{
			{"role": "user", "content": "ping"},
		})
		latency := time.Since(start).Milliseconds()
		if err != nil {
			log.Printf("[admin] LLM 测试失败: %v", err)
			c.JSON(http.StatusOK, gin.H{"ok": false, "error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{"ok": true, "latencyMs": latency, "reply": truncate(content, 50)})
	}
}

// ---------- 统计与页面 ----------

func adminStatsHandler(pool *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		stats := gin.H{"dbOk": pool != nil}
		if pool != nil {
			var users, llmConfigs int
			_ = pool.QueryRow(c.Request.Context(),
				`SELECT COUNT(*) FROM users WHERE deleted_at IS NULL`).Scan(&users)
			_ = pool.QueryRow(c.Request.Context(), `SELECT COUNT(*) FROM llm_configs`).Scan(&llmConfigs)
			stats["users"] = users
			stats["llmConfigs"] = llmConfigs
		}
		c.JSON(http.StatusOK, stats)
	}
}

// adminIndexHandler 返回管理后台单页（Go embed）
func adminIndexHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Data(http.StatusOK, "text/html; charset=utf-8", adminui.IndexHTML)
	}
}

func def(s, fallback string) string {
	if s == "" {
		return fallback
	}
	return s
}
