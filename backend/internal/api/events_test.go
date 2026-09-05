package api

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"

	"fatbattle/backend/internal/middleware"
	"fatbattle/backend/internal/repo"
)

func TestPublicConfigHidesSecretsAndUsesDefaults(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.GET("/api/v1/config/public", publicConfigHandler(nil))

	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/api/v1/config/public", nil)
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("status %d body=%s", w.Code, w.Body.String())
	}
	var body map[string]any
	if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	if _, ok := body["calorieFloor"]; !ok {
		t.Fatalf("missing calorieFloor: %v", body)
	}
	if _, ok := body["maxDailyDeficit"]; !ok {
		t.Fatalf("missing maxDailyDeficit")
	}
	for k := range body {
		if repo.IsSecretSettingKey(k) {
			t.Errorf("public config leaked secret-like key %s", k)
		}
	}
	if _, ok := body["apiKey"]; ok {
		t.Fatal("apiKey must not appear")
	}
	if _, ok := body["api_key"]; ok {
		t.Fatal("api_key must not appear")
	}
}

func TestIsSecretSettingKey(t *testing.T) {
	if !repo.IsSecretSettingKey("zhipu_api_key") || !repo.IsSecretSettingKey("JWT_SECRET") {
		t.Fatal("should flag secrets")
	}
	if repo.IsSecretSettingKey("calorie_floor") || repo.IsSecretSettingKey("coachEnabled") {
		t.Fatal("should allow public keys")
	}
}

func TestEventsRequiresAuth(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.POST("/api/v1/progress/events", middleware.Auth("test-secret", nil), eventsHandler(nil))
	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/api/v1/progress/events", strings.NewReader(`{"type":"meal"}`))
	r.ServeHTTP(w, req)
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", w.Code)
	}
}

func TestEventsDBUnavailable(t *testing.T) {
	gin.SetMode(gin.TestMode)
	token, err := middleware.SignToken("test-secret", 1)
	if err != nil {
		t.Fatal(err)
	}
	r := gin.New()
	r.POST("/api/v1/progress/events", middleware.Auth("test-secret", nil), eventsHandler(nil))
	r.GET("/api/v1/progress/summary", middleware.Auth("test-secret", nil), summaryHandler(nil))

	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/api/v1/progress/events", strings.NewReader(`{"type":"meal","payload":{"name":"饭"}}`))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	r.ServeHTTP(w, req)
	if w.Code != http.StatusServiceUnavailable {
		t.Fatalf("events expected 503, got %d body=%s", w.Code, w.Body.String())
	}

	w = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodGet, "/api/v1/progress/summary", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	r.ServeHTTP(w, req)
	if w.Code != http.StatusServiceUnavailable {
		t.Fatalf("summary expected 503, got %d", w.Code)
	}
}

func TestParseEventBatch(t *testing.T) {
	one, err := parseEventBatch([]byte(`{"type":"weight","payload":{"weightKg":70}}`))
	if err != nil || len(one) != 1 || one[0].Type != "weight" {
		t.Fatalf("single: %+v %v", one, err)
	}
	batch, err := parseEventBatch([]byte(`{"events":[{"type":"meal","payload":{"name":"蛋"}},{"type":"exercise","payload":{"name":"跑"}}]}`))
	if err != nil || len(batch) != 2 {
		t.Fatalf("batch: %+v %v", batch, err)
	}
}
