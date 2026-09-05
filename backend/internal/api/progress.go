package api

import (
	"bytes"
	"encoding/json"
	"log"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"

	"fatbattle/backend/internal/repo"
)

// 快照 JSON 上限（GameState 文本，不含视频/日记/IMU 二进制）
const maxSnapshotBytes = 1 << 20 // 1 MiB

type snapshotRequest struct {
	State     json.RawMessage `json:"state"`
	GameState json.RawMessage `json:"gameState"`
	UpdatedAt string          `json:"updatedAt"`
}

type snapshotResponse struct {
	State     json.RawMessage `json:"state"`
	UpdatedAt time.Time       `json:"updatedAt"`
	Revision  int64           `json:"revision"`
}

func snapshotJSON(req snapshotRequest) json.RawMessage {
	if len(bytes.TrimSpace(req.State)) > 0 && !bytes.Equal(bytes.TrimSpace(req.State), []byte("null")) {
		return req.State
	}
	return req.GameState
}

func parseClientUpdatedAt(raw string) time.Time {
	s := bytes.TrimSpace([]byte(raw))
	if len(s) == 0 {
		return time.Now().UTC()
	}
	str := string(s)
	layouts := []string{
		time.RFC3339Nano,
		time.RFC3339,
		"2006-01-02T15:04:05.000Z07:00",
		"2006-01-02T15:04:05.000",
		"2006-01-02T15:04:05",
	}
	for _, layout := range layouts {
		if t, err := time.Parse(layout, str); err == nil {
			return t.UTC()
		}
	}
	return time.Now().UTC()
}

func isJSONObject(raw json.RawMessage) bool {
	trim := bytes.TrimSpace(raw)
	return len(trim) >= 2 && trim[0] == '{' && json.Valid(trim)
}

func writeSnapshot(c *gin.Context, code int, row *repo.ProgressSnapshot) {
	c.JSON(code, snapshotResponse{
		State:     row.State,
		UpdatedAt: row.UpdatedAt.UTC(),
		Revision:  row.Revision,
	})
}

// snapshotHandler 进度快照上传：upsert 到 user_progress，last-write-wins（按 updatedAt）
func snapshotHandler(pool *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		if c.Request.ContentLength > maxSnapshotBytes {
			jsonError(c, http.StatusRequestEntityTooLarge, "快照过大")
			return
		}

		raw, err := c.GetRawData()
		if err != nil {
			jsonError(c, http.StatusBadRequest, "无法读取请求体")
			return
		}
		if len(raw) > maxSnapshotBytes {
			jsonError(c, http.StatusRequestEntityTooLarge, "快照过大")
			return
		}

		var req snapshotRequest
		if err := json.Unmarshal(raw, &req); err != nil {
			jsonError(c, http.StatusBadRequest, "参数错误: JSON 无法解析")
			return
		}
		state := snapshotJSON(req)
		if !isJSONObject(state) {
			jsonError(c, http.StatusBadRequest, "缺少 state / gameState 对象（GameState.toJson）")
			return
		}

		if pool == nil {
			jsonError(c, http.StatusServiceUnavailable, "数据库未就绪")
			return
		}
		userID := c.GetInt64("userID")

		clientUpdatedAt := parseClientUpdatedAt(req.UpdatedAt)

		row, conflict, err := repo.UpsertProgressSnapshot(c.Request.Context(), pool, userID, state, clientUpdatedAt)
		if err != nil {
			log.Printf("[progress] upsert snapshot user=%d: %v", userID, err)
			jsonError(c, http.StatusInternalServerError, "保存快照失败")
			return
		}
		if row == nil {
			jsonError(c, http.StatusInternalServerError, "保存快照失败")
			return
		}
		if conflict {
			c.JSON(http.StatusConflict, gin.H{
				"error":     "云端存档更新，未覆盖",
				"state":     row.State,
				"updatedAt": row.UpdatedAt.UTC(),
				"revision":  row.Revision,
			})
			return
		}
		repo.RefreshFromSnapshot(c.Request.Context(), pool, userID, state)
		writeSnapshot(c, http.StatusOK, row)
	}
}

// getSnapshotHandler 拉取最新进度快照（换机/重装恢复）
func getSnapshotHandler(pool *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		if pool == nil {
			jsonError(c, http.StatusServiceUnavailable, "数据库未就绪")
			return
		}
		userID := c.GetInt64("userID")
		row, err := repo.GetProgressSnapshot(c.Request.Context(), pool, userID)
		if err != nil {
			log.Printf("[progress] get snapshot user=%d: %v", userID, err)
			jsonError(c, http.StatusInternalServerError, "读取快照失败")
			return
		}
		if row == nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "暂无云端存档"})
			return
		}
		repo.TouchLastSeen(c.Request.Context(), pool, userID)
		writeSnapshot(c, http.StatusOK, row)
	}
}
