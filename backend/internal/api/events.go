package api

import (
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"

	"fatbattle/backend/internal/repo"
)

var allowedEventTypes = map[string]bool{
	"meal": true, "exercise": true, "battle": true, "weight": true, "sculpt_settle": true,
}

type eventIn struct {
	Type     string          `json:"type"`
	At       string          `json:"at"`
	ID       string          `json:"id"`
	ClientID string          `json:"clientId"`
	Payload  json.RawMessage `json:"payload"`
}

// eventsHandler POST /progress/events：追加流水并拆进规范化表
func eventsHandler(pool *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		if pool == nil {
			jsonError(c, http.StatusServiceUnavailable, "数据库未就绪")
			return
		}
		raw, err := c.GetRawData()
		if err != nil {
			jsonError(c, http.StatusBadRequest, "无法读取请求体")
			return
		}
		events, err := parseEventBatch(raw)
		if err != nil || len(events) == 0 {
			jsonError(c, http.StatusBadRequest, "请提交 type+payload，或 {events:[...]}")
			return
		}
		userID := c.GetInt64("userID")
		accepted := 0
		for _, ev := range events {
			typ := strings.ToLower(strings.TrimSpace(ev.Type))
			if !allowedEventTypes[typ] {
				jsonError(c, http.StatusBadRequest, "不支持的事件类型: "+ev.Type+"（meal|exercise|battle|weight|sculpt_settle）")
				return
			}
			at := parseClientUpdatedAt(ev.At)
			payload := ev.Payload
			if len(payload) == 0 {
				payload = json.RawMessage(`{}`)
			}
			if _, err := repo.InsertProgressEvent(c.Request.Context(), pool, userID, typ, payload, at); err != nil {
				jsonError(c, http.StatusInternalServerError, "写入流水失败")
				return
			}
			clientID := strings.TrimSpace(ev.ClientID)
			if clientID == "" {
				clientID = strings.TrimSpace(ev.ID)
			}
			if err := repo.FanOutEvent(c.Request.Context(), pool, userID, typ, at, payload, clientID); err != nil {
				jsonError(c, http.StatusInternalServerError, "规范化写入失败: "+err.Error())
				return
			}
			accepted++
		}
		repo.TouchLastSeen(c.Request.Context(), pool, userID)
		c.JSON(http.StatusOK, gin.H{"ok": true, "accepted": accepted})
	}
}

func parseEventBatch(raw []byte) ([]eventIn, error) {
	var batch struct {
		Events []eventIn `json:"events"`
		eventIn
	}
	if err := json.Unmarshal(raw, &batch); err != nil {
		return nil, err
	}
	if len(batch.Events) > 0 {
		return batch.Events, nil
	}
	if strings.TrimSpace(batch.Type) != "" {
		return []eventIn{batch.eventIn}, nil
	}
	return nil, nil
}

// getEventsHandler GET /progress/events?from&to&type
func getEventsHandler(pool *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		if pool == nil {
			jsonError(c, http.StatusServiceUnavailable, "数据库未就绪")
			return
		}
		userID := c.GetInt64("userID")
		from, to := queryTimeRange(c)
		items, err := repo.ListProgressEvents(c.Request.Context(), pool, userID, from, to, c.Query("type"), 100)
		if err != nil {
			jsonError(c, http.StatusInternalServerError, "查询失败")
			return
		}
		c.JSON(http.StatusOK, gin.H{"items": items})
	}
}

// summaryHandler GET /progress/summary?range=7d|30d
func summaryHandler(pool *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		if pool == nil {
			jsonError(c, http.StatusServiceUnavailable, "数据库未就绪")
			return
		}
		rng := c.DefaultQuery("range", "7d")
		if rng != "7d" && rng != "30d" {
			rng = "7d"
		}
		sum, err := repo.GetSummary(c.Request.Context(), pool, c.GetInt64("userID"), rng)
		if err != nil {
			jsonError(c, http.StatusInternalServerError, "查询失败")
			return
		}
		c.JSON(http.StatusOK, sum)
	}
}

func queryTimeRange(c *gin.Context) (from, to *time.Time) {
	if s := c.Query("from"); s != "" {
		t := parseClientUpdatedAt(s)
		from = &t
	}
	if s := c.Query("to"); s != "" {
		t := parseClientUpdatedAt(s)
		to = &t
	}
	return
}

// publicConfigHandler GET /api/v1/config/public — 运营开关，不含密钥
func publicConfigHandler(pool *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		cfg, err := repo.GetPublicSettings(c.Request.Context(), pool)
		if err != nil {
			cfg = repo.DefaultPublicSettings()
		}
		// 双保险：剔除任何看起来像密钥的键
		for k := range cfg {
			if repo.IsSecretSettingKey(k) {
				delete(cfg, k)
			}
		}
		c.JSON(http.StatusOK, cfg)
	}
}
