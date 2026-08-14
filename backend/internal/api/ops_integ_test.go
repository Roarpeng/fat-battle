package api

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"strconv"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"

	backend "fatbattle/backend"
	"fatbattle/backend/internal/middleware"
	"fatbattle/backend/internal/repo"
)

func testPool(t *testing.T) *pgxpool.Pool {
	t.Helper()
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		dsn = os.Getenv("DATABASE_URL")
	}
	if dsn == "" {
		t.Skip("set TEST_DATABASE_URL or DATABASE_URL to run integration tests")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
	t.Cleanup(cancel)
	pool, err := repo.Connect(ctx, dsn)
	if err != nil {
		t.Skipf("postgres unavailable: %v", err)
	}
	t.Cleanup(pool.Close)
	if err := backend.RunMigrations(ctx, pool); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	return pool
}

func insertTestUser(t *testing.T, pool *pgxpool.Pool) int64 {
	t.Helper()
	hash, _ := bcrypt.GenerateFromPassword([]byte("password1"), 4)
	email := "ops-" + time.Now().UTC().Format("150405.000000") + "@test.local"
	var id int64
	if err := pool.QueryRow(context.Background(),
		`INSERT INTO users (email, nickname, pass_hash) VALUES ($1,$2,$3) RETURNING id`,
		email, "测", string(hash),
	).Scan(&id); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		_, _ = pool.Exec(context.Background(), `DELETE FROM users WHERE id = $1`, id)
	})
	return id
}

func TestMigrateAppliesOpsTables(t *testing.T) {
	pool := testPool(t)
	ctx := context.Background()
	var n int
	if err := pool.QueryRow(ctx, `SELECT COUNT(*) FROM schema_migrations`).Scan(&n); err != nil {
		t.Fatal(err)
	}
	if n < 4 {
		t.Fatalf("schema_migrations rows=%d, want >=4", n)
	}
	for _, tbl := range []string{"user_profiles", "body_metrics", "exercise_sessions", "meal_logs", "sculpt_progress", "app_settings", "admin_audit_log"} {
		var exists bool
		if err := pool.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name=$1)`, tbl).Scan(&exists); err != nil || !exists {
			t.Fatalf("missing table %s: %v", tbl, err)
		}
	}
}

func TestSnapshotUpsertsProfile(t *testing.T) {
	pool := testPool(t)
	uid := insertTestUser(t, pool)
	gin.SetMode(gin.TestMode)
	token, _ := middleware.SignToken("s", uid)
	r := gin.New()
	r.POST("/api/v1/progress/snapshot", middleware.Auth("s", nil), snapshotHandler(pool))

	state := `{
		"user":{"nickname":"阿锻","gender":"male","height":178,"weight":82.4,"targetWeight":75,"age":31,"sculptLine":"david","sleepType":0,"kneeIssue":false},
		"targetCal":1900,"streak":6,"sculptStage":2,"sculptProgress":0.4,"sculptSettledCount":4,"visualTheme":"sketch",
		"lastDate":"2026-08-13",
		"weightRecords":[{"date":"2026-08-13","weight":82.4}]
	}`
	body := `{"state":` + state + `,"updatedAt":"2026-08-13T10:00:00Z"}`
	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/api/v1/progress/snapshot", bytes.NewReader([]byte(body)))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("snapshot %d %s", w.Code, w.Body.String())
	}
	p, err := repo.GetProfile(context.Background(), pool, uid)
	if err != nil || p == nil {
		t.Fatalf("profile: %v %+v", err, p)
	}
	if p.Nickname == nil || *p.Nickname != "阿锻" {
		t.Fatalf("nickname %+v", p.Nickname)
	}
	if p.Gender == nil || *p.Gender != "male" {
		t.Fatalf("gender %+v", p.Gender)
	}
	if p.CalorieFloor == nil || *p.CalorieFloor != 1500 {
		t.Fatalf("floor %+v", p.CalorieFloor)
	}
	sc, err := repo.GetSculpt(context.Background(), pool, uid)
	if err != nil || sc == nil || sc.Stage != 2 || sc.Line != "david" {
		t.Fatalf("sculpt %+v %v", sc, err)
	}
}

func TestEventsWriteSessionAndMeal(t *testing.T) {
	pool := testPool(t)
	uid := insertTestUser(t, pool)
	gin.SetMode(gin.TestMode)
	token, _ := middleware.SignToken("s", uid)
	r := gin.New()
	r.POST("/api/v1/progress/events", middleware.Auth("s", nil), eventsHandler(pool))

	payload := `{
		"events":[
			{"type":"meal","at":"2026-08-13T08:00:00Z","id":"m1","payload":{"name":"豆浆","grams":300,"calories":120,"mealSlot":"breakfast","source":"manual"}},
			{"type":"exercise","at":"2026-08-13T19:00:00Z","id":"e1","payload":{"lessonName":"深蹲课","mode":"camera","caloriesBurned":180,"damageDealt":40,"totalReps":30,"feel":"ok","settled":true}}
		]
	}`
	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/api/v1/progress/events", bytes.NewReader([]byte(payload)))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("events %d %s", w.Code, w.Body.String())
	}
	meals, err := repo.ListMeals(context.Background(), pool, uid, nil, nil, 10)
	if err != nil || len(meals) == 0 || meals[0].Name != "豆浆" {
		t.Fatalf("meals %+v %v", meals, err)
	}
	sess, err := repo.ListSessions(context.Background(), pool, uid, nil, nil, 10)
	if err != nil || len(sess) == 0 || sess[0].LessonName == nil || *sess[0].LessonName != "深蹲课" {
		t.Fatalf("sessions %+v %v", sess, err)
	}
}

func TestAdminPatchProgressAudits(t *testing.T) {
	pool := testPool(t)
	uid := insertTestUser(t, pool)
	hash, _ := bcrypt.GenerateFromPassword([]byte("adminpass"), 4)
	var adminID int64
	if err := pool.QueryRow(context.Background(),
		`INSERT INTO admin_users (username, pass_hash, role) VALUES ($1,$2,'admin') RETURNING id`,
		"ops-admin-"+time.Now().Format("150405.000000"), string(hash),
	).Scan(&adminID); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		_, _ = pool.Exec(context.Background(), `DELETE FROM admin_users WHERE id=$1`, adminID)
	})

	gin.SetMode(gin.TestMode)
	tok, _ := middleware.SignAdminToken("admin-s", adminID)
	r := gin.New()
	r.PATCH("/api/admin/users/:id/progress", middleware.AdminAuth("admin-s"), adminUserProgressHandler(pool))

	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPatch, "/api/admin/users/"+strconv.FormatInt(uid, 10)+"/progress",
		bytes.NewReader([]byte(`{"targetCal":1750,"sculptStage":4,"sculptLine":"venus","streak":9}`)))
	req.Header.Set("Authorization", "Bearer "+tok)
	req.Header.Set("Content-Type", "application/json")
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("patch %d %s", w.Code, w.Body.String())
	}
	audits, err := repo.ListAudit(context.Background(), pool, &uid, 10)
	if err != nil || len(audits) == 0 {
		t.Fatalf("audit %+v %v", audits, err)
	}
	if audits[0].Action != "user.progress" {
		t.Fatalf("action %s", audits[0].Action)
	}
	sc, _ := repo.GetSculpt(context.Background(), pool, uid)
	if sc == nil || sc.Stage != 4 || sc.Line != "venus" {
		t.Fatalf("sculpt %+v", sc)
	}
	p, _ := repo.GetProfile(context.Background(), pool, uid)
	if p == nil || p.TargetCal == nil || *p.TargetCal != 1750 || p.Streak != 9 {
		t.Fatalf("profile %+v", p)
	}
}

func TestPublicConfigFromDBHidesSecrets(t *testing.T) {
	pool := testPool(t)
	_, _ = pool.Exec(context.Background(),
		`INSERT INTO app_settings (key, value) VALUES ('zhipu_api_key', '"sk-secret"') ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value`)
	t.Cleanup(func() {
		_, _ = pool.Exec(context.Background(), `DELETE FROM app_settings WHERE key='zhipu_api_key'`)
	})
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.GET("/api/v1/config/public", publicConfigHandler(pool))
	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/api/v1/config/public", nil)
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatal(w.Body.String())
	}
	var body map[string]any
	_ = json.Unmarshal(w.Body.Bytes(), &body)
	raw := w.Body.String()
	if _, ok := body["calorieFloor"]; !ok {
		t.Fatalf("missing public fields %s", raw)
	}
	if bytes.Contains(w.Body.Bytes(), []byte("sk-secret")) || bytes.Contains(w.Body.Bytes(), []byte("zhipu_api_key")) {
		t.Fatalf("leaked secret: %s", raw)
	}
}
