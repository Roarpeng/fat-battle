// 数据库迁移与种子数据（模块根包：embed 需要与 migrations 目录同层）
package backend

import (
	"context"
	"embed"
	"fmt"
	"log"
	"sort"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"
)

//go:embed migrations/*.sql
var migrationsFS embed.FS

// MigrationFiles 返回按文件名排序的全部迁移文件名（供测试断言）。
func MigrationFiles() ([]string, error) {
	entries, err := migrationsFS.ReadDir("migrations")
	if err != nil {
		return nil, err
	}
	names := make([]string, 0, len(entries))
	for _, e := range entries {
		if !e.IsDir() && strings.HasSuffix(e.Name(), ".sql") {
			names = append(names, e.Name())
		}
	}
	sort.Strings(names)
	return names, nil
}

// RunMigrations 按文件名顺序执行 migrations 目录下的全部 SQL。
// 使用 schema_migrations 跳过已成功执行的文件；SQL 本身须幂等（IF NOT EXISTS）。
// 注：docker-entrypoint-initdb.d 只对全新数据卷生效，且 compose 只挂 0001；
// 0002 及之后必须靠本函数在 API 启动时补齐。
func RunMigrations(ctx context.Context, pool *pgxpool.Pool) error {
	if _, err := pool.Exec(ctx, `
		CREATE TABLE IF NOT EXISTS schema_migrations (
			filename   TEXT PRIMARY KEY,
			applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
		)`); err != nil {
		return fmt.Errorf("创建 schema_migrations: %w", err)
	}

	names, err := MigrationFiles()
	if err != nil {
		return fmt.Errorf("读取迁移目录: %w", err)
	}

	for _, name := range names {
		var already bool
		if err := pool.QueryRow(ctx,
			`SELECT EXISTS(SELECT 1 FROM schema_migrations WHERE filename = $1)`, name,
		).Scan(&already); err != nil {
			return fmt.Errorf("查询迁移状态 %s: %w", name, err)
		}
		if already {
			log.Printf("[migrate] 跳过已执行 %s", name)
			continue
		}
		sqlBytes, err := migrationsFS.ReadFile("migrations/" + name)
		if err != nil {
			return fmt.Errorf("读取迁移 %s: %w", name, err)
		}
		if _, err := pool.Exec(ctx, string(sqlBytes)); err != nil {
			return fmt.Errorf("执行迁移 %s: %w", name, err)
		}
		if _, err := pool.Exec(ctx,
			`INSERT INTO schema_migrations (filename) VALUES ($1) ON CONFLICT DO NOTHING`, name,
		); err != nil {
			return fmt.Errorf("记录迁移 %s: %w", name, err)
		}
		log.Printf("[migrate] 已执行 %s", name)
	}
	return nil
}

// SeedAdmin 首次启动时创建种子管理员（admin_users 为空时）。
// 账号密码来自环境变量 ADMIN_USER / ADMIN_PASS。
func SeedAdmin(ctx context.Context, pool *pgxpool.Pool, username, password string) error {
	var count int
	if err := pool.QueryRow(ctx, `SELECT COUNT(*) FROM admin_users`).Scan(&count); err != nil {
		return fmt.Errorf("查询管理员数量: %w", err)
	}
	if count > 0 {
		return nil
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(password), 10)
	if err != nil {
		return fmt.Errorf("加密种子密码: %w", err)
	}
	if _, err := pool.Exec(ctx,
		`INSERT INTO admin_users (username, pass_hash, role) VALUES ($1, $2, 'admin')`,
		username, string(hash),
	); err != nil {
		return fmt.Errorf("创建种子管理员: %w", err)
	}
	log.Printf("[seed] 已创建默认管理员: %s（请尽快在管理后台/环境变量修改密码）", username)
	return nil
}
