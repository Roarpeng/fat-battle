package tokenstore

import (
	"context"
	"testing"
	"time"
)

func TestMemoryDenylist(t *testing.T) {
	dl := NewMemory()
	ctx := context.Background()

	denied, err := dl.Denied(ctx, "abc")
	if err != nil || denied {
		t.Fatalf("empty denylist should miss, got denied=%v err=%v", denied, err)
	}

	if err := dl.Deny(ctx, "abc", 50*time.Millisecond); err != nil {
		t.Fatal(err)
	}
	denied, err = dl.Denied(ctx, "abc")
	if err != nil || !denied {
		t.Fatalf("expected denied, got denied=%v err=%v", denied, err)
	}

	time.Sleep(80 * time.Millisecond)
	denied, err = dl.Denied(ctx, "abc")
	if err != nil || denied {
		t.Fatalf("expired entry should miss, got denied=%v err=%v", denied, err)
	}
}

func TestNopDenylist(t *testing.T) {
	var dl Nop
	ctx := context.Background()
	if err := dl.Deny(ctx, "x", time.Hour); err != nil {
		t.Fatal(err)
	}
	denied, err := dl.Denied(ctx, "x")
	if err != nil || denied {
		t.Fatalf("nop should never deny, got denied=%v err=%v", denied, err)
	}
}
