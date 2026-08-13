package repo

import (
	"testing"
	"time"
)

func TestClientWinsLastWrite(t *testing.T) {
	server := time.Date(2026, 8, 13, 10, 0, 0, 0, time.UTC)
	older := server.Add(-time.Minute)
	newer := server.Add(time.Minute)

	if ClientWins(server, older) {
		t.Fatal("older client must not overwrite server")
	}
	if !ClientWins(server, newer) {
		t.Fatal("newer client must overwrite server")
	}
	if !ClientWins(server, server) {
		t.Fatal("equal timestamp: client retry should win")
	}
	if !ClientWins(time.Time{}, newer) {
		t.Fatal("empty server timestamp should accept client")
	}
}
