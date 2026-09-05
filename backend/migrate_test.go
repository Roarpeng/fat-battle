package backend

import (
	"strings"
	"testing"
)

func TestMigrationFilesAreCompleteAndOrdered(t *testing.T) {
	names, err := MigrationFiles()
	if err != nil {
		t.Fatal(err)
	}
	if len(names) < 4 {
		t.Fatalf("expected at least 0001-0004, got %v", names)
	}
	wantPrefix := []string{"0001_init.sql", "0002_admin_llm.sql", "0003_progress_revision.sql", "0004_ops_tables.sql"}
	for i, w := range wantPrefix {
		if names[i] != w {
			t.Fatalf("migration[%d]=%s want %s (all=%v)", i, names[i], w, names)
		}
	}
	sql, err := migrationsFS.ReadFile("migrations/0004_ops_tables.sql")
	if err != nil {
		t.Fatal(err)
	}
	body := string(sql)
	for _, tbl := range []string{
		"user_profiles", "body_metrics", "exercise_sessions", "meal_logs",
		"sculpt_progress", "app_settings", "admin_audit_log",
	} {
		if !strings.Contains(body, tbl) {
			t.Errorf("0004 missing table %s", tbl)
		}
	}
}
