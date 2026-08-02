// 数据库迁移与种子数据（模块根包：embed 需要与 migrations 目录同层）
package backend

import (
	"context"
	"embed"
	"fmt"
	"log"
	"sort"

	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"
)

//go:embed migrations/*.sql
var migrationsFS embed.FS

// RunMigrations 按文件名顺序执行 migrations 目录下的全部 SQL（幂等：IF NOT EXISTS）。
// 注：docker-entrypoint-initdb.d 只对全新数据卷生效，老库必须靠这里补迁移。
func RunMigrations(ctx context.Context, pool *pgxpool.Pool) error {
	entries, err := migrationsFS.ReadDir("migrations")
	if err != nil {
		return fmt.Errorf("读取迁移目录: %w", err)
	}
	names := make([]string, 0, len(entries))
	for _, e := range entries {
		if !e.IsDir() {
			names = append(names, e.Name())
		}
	}
	sort.Strings(names)

	for _, name := range names {
		sqlBytes, err := migrationsFS.ReadFile("migrations/" + name)
		if err != nil {
			return fmt.Errorf("读取迁移 %s: %w", name, err)
		}
		if _, err := pool.Exec(ctx, string(sqlBytes)); err != nil {
			return fmt.Errorf("执行迁移 %s: %w", name, err)
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
