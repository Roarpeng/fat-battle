package api

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"

	"fatbattle/backend/internal/domain"
	"fatbattle/backend/internal/repo"
)

func adminActor(c *gin.Context, pool *pgxpool.Pool) (id int64, name string) {
	id = c.GetInt64("adminID")
	name = "admin"
	if pool != nil {
		_ = pool.QueryRow(c.Request.Context(),
			`SELECT username FROM admin_users WHERE id = $1`, id).Scan(&name)
	}
	return
}

func parseUserIDParam(c *gin.Context) (int64, bool) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil || id <= 0 {
		jsonError(c, http.StatusBadRequest, "用户 ID 无效")
		return 0, false
	}
	return id, true
}

func requireDB(c *gin.Context, pool *pgxpool.Pool) bool {
	if pool == nil {
		jsonError(c, http.StatusServiceUnavailable, "数据库未就绪")
		return false
	}
	return true
}

// adminUserGetHandler GET /api/admin/users/:id 档案卷宗
func adminUserGetHandler(pool *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		if !requireDB(c, pool) {
			return
		}
		id, ok := parseUserIDParam(c)
		if !ok {
			return
		}
		var email, nickname string
		var createdAt time.Time
		var isDisabled bool
		err := pool.QueryRow(c.Request.Context(),
			`SELECT email, nickname, created_at, is_disabled FROM users WHERE id = $1 AND deleted_at IS NULL`,
			id).Scan(&email, &nickname, &createdAt, &isDisabled)
		if err != nil {
			jsonError(c, http.StatusNotFound, "用户不存在")
			return
		}
		profile, _ := repo.GetProfile(c.Request.Context(), pool, id)
		sculpt, _ := repo.GetSculpt(c.Request.Context(), pool, id)
		snap, _ := repo.GetProgressSnapshot(c.Request.Context(), pool, id)
		meta := gin.H{"hasState": false}
		if snap != nil {
			meta["hasState"] = true
			meta["updatedAt"] = snap.UpdatedAt.UTC()
			meta["revision"] = snap.Revision
		}
		c.JSON(http.StatusOK, gin.H{
			"user": gin.H{
				"id": id, "email": email, "nickname": nickname,
				"createdAt": createdAt, "isDisabled": isDisabled,
			},
			"profile":  profile,
			"sculpt":   sculpt,
			"snapshot": meta,
		})
	}
}

// adminUserPatchHandler PATCH /api/admin/users/:id 档案字段
func adminUserPatchHandler(pool *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		if !requireDB(c, pool) {
			return
		}
		id, ok := parseUserIDParam(c)
		if !ok {
			return
		}
		var body map[string]any
		if err := c.ShouldBindJSON(&body); err != nil {
			jsonError(c, http.StatusBadRequest, "参数错误")
			return
		}
		before, _ := repo.GetProfile(c.Request.Context(), pool, id)
		allow := map[string]bool{
			"nickname": true, "avatar": true, "age": true, "gender": true,
			"heightCm": true, "weightKg": true, "targetWeightKg": true, "bmi": true,
			"sleepType": true, "workType": true, "exerciseTime": true, "characterStyle": true,
			"difficulty": true, "fitnessLevel": true, "pushupCount": true,
			"runDurationMin": true, "runDuration": true, "weeklyFreq": true,
			"visualTheme": true, "sculptLine": true, "kneeIssue": true, "waistIssue": true,
			"targetCal": true, "calorieFloor": true, "streak": true,
		}
		fields := map[string]any{}
		for k, v := range body {
			if k == "runDuration" {
				k = "runDurationMin"
			}
			if allow[k] {
				fields[k] = v
			}
		}
		if nick, ok := fields["nickname"].(string); ok && nick != "" {
			_, _ = pool.Exec(c.Request.Context(),
				`UPDATE users SET nickname = $1 WHERE id = $2 AND deleted_at IS NULL`, nick, id)
		}
		if err := repo.PatchProfile(c.Request.Context(), pool, id, fields); err != nil {
			jsonError(c, http.StatusInternalServerError, "更新失败: "+err.Error())
			return
		}
		after, _ := repo.GetProfile(c.Request.Context(), pool, id)
		aid, aname := adminActor(c, pool)
		tid := id
		repo.WriteAudit(c.Request.Context(), pool, aid, aname, "user.patch", &tid, before, after)
		c.JSON(http.StatusOK, gin.H{"ok": true, "profile": after})
	}
}

func adminUserSessionsHandler(pool *pgxpool.Pool) gin.HandlerFunc {
	return adminListByUser(pool, "sessions")
}
func adminUserMealsHandler(pool *pgxpool.Pool) gin.HandlerFunc {
	return adminListByUser(pool, "meals")
}
func adminUserMetricsHandler(pool *pgxpool.Pool) gin.HandlerFunc {
	return adminListByUser(pool, "metrics")
}
func adminUserEventsHandler(pool *pgxpool.Pool) gin.HandlerFunc {
	return adminListByUser(pool, "events")
}

func adminListByUser(pool *pgxpool.Pool, kind string) gin.HandlerFunc {
	return func(c *gin.Context) {
		if !requireDB(c, pool) {
			return
		}
		id, ok := parseUserIDParam(c)
		if !ok {
			return
		}
		from, to := queryTimeRange(c)
		limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
		var items any
		var err error
		switch kind {
		case "sessions":
			items, err = repo.ListSessions(c.Request.Context(), pool, id, from, to, limit)
		case "meals":
			items, err = repo.ListMeals(c.Request.Context(), pool, id, from, to, limit)
		case "metrics":
			items, err = repo.ListMetrics(c.Request.Context(), pool, id, limit)
		case "events":
			items, err = repo.ListProgressEvents(c.Request.Context(), pool, id, from, to, c.Query("type"), limit)
		}
		if err != nil {
			jsonError(c, http.StatusInternalServerError, "查询失败: "+err.Error())
			return
		}
		c.JSON(http.StatusOK, gin.H{"items": items})
	}
}

func adminSessionsHandler(pool *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		if !requireDB(c, pool) {
			return
		}
		uid, _ := strconv.ParseInt(c.Query("userId"), 10, 64)
		from, to := queryTimeRange(c)
		limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
		items, err := repo.ListSessions(c.Request.Context(), pool, uid, from, to, limit)
		if err != nil {
			jsonError(c, http.StatusInternalServerError, "查询失败: "+err.Error())
			return
		}
		c.JSON(http.StatusOK, gin.H{"items": items})
	}
}

func adminMealsHandler(pool *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		if !requireDB(c, pool) {
			return
		}
		uid, _ := strconv.ParseInt(c.Query("userId"), 10, 64)
		from, to := queryTimeRange(c)
		limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
		items, err := repo.ListMeals(c.Request.Context(), pool, uid, from, to, limit)
		if err != nil {
			jsonError(c, http.StatusInternalServerError, "查询失败: "+err.Error())
			return
		}
		c.JSON(http.StatusOK, gin.H{"items": items})
	}
}

// adminUserProgressHandler PATCH /api/admin/users/:id/progress
func adminUserProgressHandler(pool *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		if !requireDB(c, pool) {
			return
		}
		id, ok := parseUserIDParam(c)
		if !ok {
			return
		}
		var req struct {
			Weight       *float64 `json:"weight"`
			TargetWeight *float64 `json:"targetWeight"`
			TargetCal    *int     `json:"targetCal"`
			Streak       *int     `json:"streak"`
			SculptStage  *int     `json:"sculptStage"`
			SculptLine   *string  `json:"sculptLine"`
			VisualTheme  *string  `json:"visualTheme"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			jsonError(c, http.StatusBadRequest, "参数错误")
			return
		}
		beforeProf, _ := repo.GetProfile(c.Request.Context(), pool, id)
		beforeSculpt, _ := repo.GetSculpt(c.Request.Context(), pool, id)
		beforeSnap, _ := repo.GetProgressSnapshot(c.Request.Context(), pool, id)

		fields := map[string]any{}
		patchJSON := map[string]any{}
		if req.Weight != nil {
			fields["weightKg"] = *req.Weight
			patchJSON["weight"] = *req.Weight
			_ = repo.UpsertBodyMetric(c.Request.Context(), pool, id, time.Now().UTC(), req.Weight, nil, "admin")
		}
		if req.TargetWeight != nil {
			fields["targetWeightKg"] = *req.TargetWeight
			patchJSON["targetWeight"] = *req.TargetWeight
		}
		if req.TargetCal != nil {
			fields["targetCal"] = *req.TargetCal
			patchJSON["targetCal"] = *req.TargetCal
		}
		if req.Streak != nil {
			fields["streak"] = *req.Streak
			patchJSON["streak"] = *req.Streak
		}
		if req.VisualTheme != nil {
			th := strings.ToLower(*req.VisualTheme)
			fields["visualTheme"] = th
			patchJSON["visualTheme"] = th
		}
		if req.SculptLine != nil {
			line := strings.ToLower(*req.SculptLine)
			if line != "david" && line != "venus" {
				jsonError(c, http.StatusBadRequest, "雕塑线只能是 david 或 venus")
				return
			}
			fields["sculptLine"] = line
			patchJSON["sculptLine"] = line
		}
		if req.SculptStage != nil {
			st := *req.SculptStage
			if st < 0 || st > 7 {
				jsonError(c, http.StatusBadRequest, "雕塑阶段须为 0–7")
				return
			}
			prog := float64(st) / 7.0
			if st <= 4 {
				prog = float64(st) / 4.0
			} else {
				prog = 1
			}
			var maint *string
			m := "none"
			switch st {
			case 5:
				m = "polish"
			case 6:
				m = "dust"
			case 7:
				m = "rebound"
			}
			maint = &m
			_ = repo.PatchSculpt(c.Request.Context(), pool, id, req.SculptStage, req.SculptLine, &prog, maint)
			patchJSON["sculptStage"] = st
			patchJSON["sculptProgress"] = prog
			patchJSON["sculptMaintenance"] = st >= 5
		} else if req.SculptLine != nil {
			_ = repo.PatchSculpt(c.Request.Context(), pool, id, nil, req.SculptLine, nil, nil)
		}

		if err := repo.PatchProfile(c.Request.Context(), pool, id, fields); err != nil {
			jsonError(c, http.StatusInternalServerError, "更新档案失败: "+err.Error())
			return
		}

		if len(patchJSON) > 0 {
			var raw json.RawMessage
			if beforeSnap != nil {
				raw = beforeSnap.State
			} else {
				raw = json.RawMessage(`{}`)
			}
			patched, err := domain.PatchGameStateJSON(raw, patchJSON)
			if err == nil {
				_, _, _ = repo.UpsertProgressSnapshot(c.Request.Context(), pool, id, patched, time.Now().UTC())
			}
		}

		afterProf, _ := repo.GetProfile(c.Request.Context(), pool, id)
		afterSculpt, _ := repo.GetSculpt(c.Request.Context(), pool, id)
		aid, aname := adminActor(c, pool)
		tid := id
		repo.WriteAudit(c.Request.Context(), pool, aid, aname, "user.progress", &tid,
			gin.H{"profile": beforeProf, "sculpt": beforeSculpt},
			gin.H{"profile": afterProf, "sculpt": afterSculpt, "patch": patchJSON},
		)
		c.JSON(http.StatusOK, gin.H{"ok": true, "profile": afterProf, "sculpt": afterSculpt})
	}
}

func adminSettingsGetHandler(pool *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		if !requireDB(c, pool) {
			return
		}
		all, err := repo.GetAllSettings(c.Request.Context(), pool)
		if err != nil {
			jsonError(c, http.StatusInternalServerError, "查询失败")
			return
		}
		items := gin.H{}
		for k, v := range all {
			if repo.IsSecretSettingKey(k) {
				continue
			}
			var decoded any
			if json.Unmarshal(v, &decoded) == nil {
				items[k] = decoded
			} else {
				items[k] = json.RawMessage(v)
			}
		}
		c.JSON(http.StatusOK, gin.H{"items": items})
	}
}

func adminSettingsPutHandler(pool *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		if !requireDB(c, pool) {
			return
		}
		var body map[string]any
		if err := c.ShouldBindJSON(&body); err != nil {
			jsonError(c, http.StatusBadRequest, "参数错误")
			return
		}
		before, _ := repo.GetAllSettings(c.Request.Context(), pool)
		kv := map[string]json.RawMessage{}
		alias := map[string]string{
			"calorieFloor": "calorie_floor", "maxDailyDeficit": "max_daily_deficit",
			"coachEnabled": "coach_enabled", "foodRecognizeEnabled": "food_recognize_enabled",
			"defaultVisualTheme":      "default_visual_theme",
			"sculptSessionThresholds": "sculpt_session_thresholds",
		}
		allowed := map[string]bool{
			"calorie_floor": true, "max_daily_deficit": true, "coach_enabled": true,
			"food_recognize_enabled": true, "default_visual_theme": true,
			"sculpt_session_thresholds": true,
		}
		for k, v := range body {
			if nk, ok := alias[k]; ok {
				k = nk
			}
			if !allowed[k] || repo.IsSecretSettingKey(k) {
				continue
			}
			b, err := json.Marshal(v)
			if err != nil {
				continue
			}
			kv[k] = b
		}
		if len(kv) == 0 {
			jsonError(c, http.StatusBadRequest, "没有可更新的配置项")
			return
		}
		if err := repo.PutSettings(c.Request.Context(), pool, kv); err != nil {
			jsonError(c, http.StatusInternalServerError, "保存失败")
			return
		}
		after, _ := repo.GetAllSettings(c.Request.Context(), pool)
		aid, aname := adminActor(c, pool)
		repo.WriteAudit(c.Request.Context(), pool, aid, aname, "settings.put", nil, before, after)
		c.JSON(http.StatusOK, gin.H{"ok": true})
	}
}

func adminAuditHandler(pool *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		if !requireDB(c, pool) {
			return
		}
		var target *int64
		if s := c.Query("userId"); s != "" {
			if id, err := strconv.ParseInt(s, 10, 64); err == nil {
				target = &id
			}
		}
		limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
		items, err := repo.ListAudit(c.Request.Context(), pool, target, limit)
		if err != nil {
			jsonError(c, http.StatusInternalServerError, "查询失败")
			return
		}
		c.JSON(http.StatusOK, gin.H{"items": items})
	}
}
