package api

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gin-gonic/gin"

	"fatbattle/backend/internal/middleware"
)

func TestSnapshotJSONPrefersState(t *testing.T) {
	req := snapshotRequest{
		State:     json.RawMessage(`{"day":2}`),
		GameState: json.RawMessage(`{"day":1}`),
	}
	got := string(snapshotJSON(req))
	if got != `{"day":2}` {
		t.Fatalf("expected state field, got %s", got)
	}
}

func TestSnapshotJSONFallsBackToGameState(t *testing.T) {
	req := snapshotRequest{GameState: json.RawMessage(`{"lastDate":"2026-08-13"}`)}
	got := string(snapshotJSON(req))
	if got != `{"lastDate":"2026-08-13"}` {
		t.Fatalf("expected gameState fallback, got %s", got)
	}
}

func TestIsJSONObject(t *testing.T) {
	cases := []struct {
		in   string
		want bool
	}{
		{`{"a":1}`, true},
		{`  {"a":1}  `, true},
		{`[1,2]`, false},
		{`"str"`, false},
		{`null`, false},
		{``, false},
		{`{`, false},
	}
	for _, tc := range cases {
		if got := isJSONObject(json.RawMessage(tc.in)); got != tc.want {
			t.Errorf("isJSONObject(%q)=%v want %v", tc.in, got, tc.want)
		}
	}
}

func TestGetSnapshotUnauthorized(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.GET("/api/v1/progress/snapshot", middleware.Auth("test-secret", nil), getSnapshotHandler(nil))

	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/api/v1/progress/snapshot", nil)
	r.ServeHTTP(w, req)
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d body=%s", w.Code, w.Body.String())
	}
}

func TestGetSnapshotDBUnavailable(t *testing.T) {
	gin.SetMode(gin.TestMode)
	token, err := middleware.SignToken("test-secret", 42)
	if err != nil {
		t.Fatal(err)
	}
	r := gin.New()
	r.GET("/api/v1/progress/snapshot", middleware.Auth("test-secret", nil), getSnapshotHandler(nil))

	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/api/v1/progress/snapshot", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	r.ServeHTTP(w, req)
	if w.Code != http.StatusServiceUnavailable {
		t.Fatalf("expected 503, got %d body=%s", w.Code, w.Body.String())
	}
}

func TestPostSnapshotRejectsNonObject(t *testing.T) {
	gin.SetMode(gin.TestMode)
	token, err := middleware.SignToken("test-secret", 1)
	if err != nil {
		t.Fatal(err)
	}
	r := gin.New()
	r.POST("/api/v1/progress/snapshot", middleware.Auth("test-secret", nil), snapshotHandler(nil))

	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/api/v1/progress/snapshot", strings.NewReader(`{"state":[1,2]}`))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	r.ServeHTTP(w, req)
	if w.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d body=%s", w.Code, w.Body.String())
	}
}

func TestPostSnapshotInvalidJSON(t *testing.T) {
	gin.SetMode(gin.TestMode)
	token, err := middleware.SignToken("test-secret", 1)
	if err != nil {
		t.Fatal(err)
	}
	r := gin.New()
	r.POST("/api/v1/progress/snapshot", middleware.Auth("test-secret", nil), snapshotHandler(nil))

	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/api/v1/progress/snapshot", strings.NewReader(`not-json`))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	r.ServeHTTP(w, req)
	if w.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d body=%s", w.Code, w.Body.String())
	}
}

func TestEventsStillNotImplemented(t *testing.T) {
	gin.SetMode(gin.TestMode)
	token, err := middleware.SignToken("test-secret", 1)
	if err != nil {
		t.Fatal(err)
	}
	r := gin.New()
	r.POST("/api/v1/progress/events", middleware.Auth("test-secret", nil), eventsHandler())
	r.GET("/api/v1/progress/summary", middleware.Auth("test-secret", nil), summaryHandler())

	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/api/v1/progress/events", strings.NewReader(`{}`))
	req.Header.Set("Authorization", "Bearer "+token)
	r.ServeHTTP(w, req)
	if w.Code != http.StatusNotImplemented {
		t.Fatalf("events expected 501, got %d", w.Code)
	}

	w = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodGet, "/api/v1/progress/summary", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	r.ServeHTTP(w, req)
	if w.Code != http.StatusNotImplemented {
		t.Fatalf("summary expected 501, got %d", w.Code)
	}
}

func TestParseClientUpdatedAt(t *testing.T) {
	z := parseClientUpdatedAt("2026-08-13T04:00:00Z")
	if !z.Equal(time.Date(2026, 8, 13, 4, 0, 0, 0, time.UTC)) {
		t.Fatalf("RFC3339: got %v", z)
	}
	nano := parseClientUpdatedAt("2026-08-13T04:00:00.000Z")
	if !nano.Equal(time.Date(2026, 8, 13, 4, 0, 0, 0, time.UTC)) {
		t.Fatalf("Dart iso: got %v", nano)
	}
	empty := parseClientUpdatedAt("")
	if empty.IsZero() {
		t.Fatal("empty should default to now")
	}
}
