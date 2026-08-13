package middleware

import (
	"testing"
	"time"
)

func TestSignAndParseTokenMeta(t *testing.T) {
	const secret = "test-secret"
	raw, err := SignToken(secret, 42)
	if err != nil {
		t.Fatal(err)
	}
	meta, err := ParseTokenMeta(secret, raw)
	if err != nil {
		t.Fatal(err)
	}
	if meta.UserID != 42 {
		t.Fatalf("userID=%d", meta.UserID)
	}
	if meta.ID == "" {
		t.Fatal("expected jti")
	}
	if time.Until(meta.Exp) < time.Hour {
		t.Fatalf("access exp too soon: %v", meta.Exp)
	}

	refresh, err := SignRefreshToken(secret, 42)
	if err != nil {
		t.Fatal(err)
	}
	rm, err := ParseTokenMeta(secret, refresh)
	if err != nil {
		t.Fatal(err)
	}
	if rm.ID == meta.ID {
		t.Fatal("access and refresh jti should differ")
	}
}

func TestParseTokenMetaRejectsBadSecret(t *testing.T) {
	raw, err := SignToken("a", 1)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := ParseTokenMeta("b", raw); err == nil {
		t.Fatal("expected signature error")
	}
}
