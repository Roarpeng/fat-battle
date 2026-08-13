package api

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestLLMProviderHeaderUsesPickedConfig(t *testing.T) {
	if got := llmProviderHeader(&llmConfig{Provider: "qwen"}); got != "qwen" {
		t.Fatalf("qwen -> %q", got)
	}
	if got := llmProviderHeader(&llmConfig{Provider: "openai-compatible"}); got != "openai-compatible" {
		t.Fatalf("openai-compatible -> %q", got)
	}
	if got := llmProviderHeader(&llmConfig{Provider: "zhipu"}); got != "zhipu" {
		t.Fatalf("zhipu still allowed when actually picked, got %q", got)
	}
	if got := llmProviderHeader(nil); got != "" {
		t.Fatalf("nil -> %q", got)
	}
}

func TestWriteLLMProviderHeaderEmitsPickedProvider(t *testing.T) {
	gin.SetMode(gin.TestMode)
	cases := []struct {
		provider string
		want     string
	}{
		{"qwen", "qwen"},
		{"openai-compatible", "openai-compatible"},
		{"zhipu", "zhipu"},
	}
	for _, tc := range cases {
		r := gin.New()
		r.GET("/h", func(c *gin.Context) {
			writeLLMProviderHeader(c, &llmConfig{Provider: tc.provider})
			c.JSON(http.StatusOK, gin.H{"ok": true})
		})
		w := httptest.NewRecorder()
		req := httptest.NewRequest(http.MethodGet, "/h", nil)
		r.ServeHTTP(w, req)
		if got := w.Header().Get("X-Provider"); got != tc.want {
			t.Fatalf("provider %s: X-Provider=%q want %q", tc.provider, got, tc.want)
		}
	}
}

func TestFoodAndCoachErrorsDoNotHardcodeZhipu(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.GET("/food-err", func(c *gin.Context) { foodError(c, http.StatusBadRequest, "x") })
	r.GET("/coach-err", func(c *gin.Context) { coachError(c, http.StatusBadRequest, "x") })

	for _, path := range []string{"/food-err", "/coach-err"} {
		w := httptest.NewRecorder()
		req := httptest.NewRequest(http.MethodGet, path, nil)
		r.ServeHTTP(w, req)
		if got := w.Header().Get("X-Provider"); got == "zhipu" {
			t.Fatalf("%s hardcoded X-Provider=zhipu", path)
		}
	}
}
