package repo

import (
	"context"
	"encoding/json"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// ProgressSnapshot 用户最新 GameState 快照（user_progress 一行）
type ProgressSnapshot struct {
	State     json.RawMessage
	UpdatedAt time.Time
	Revision  int64
}

// ClientWins last-write-wins：客户端 updatedAt >= 服务端时允许覆盖。
// 零值服务端时间视为无存档。
func ClientWins(serverUpdatedAt, clientUpdatedAt time.Time) bool {
	if serverUpdatedAt.IsZero() {
		return true
	}
	return !serverUpdatedAt.After(clientUpdatedAt)
}

// GetProgressSnapshot 拉取用户最新快照；无存档时返回 (nil, nil)
func GetProgressSnapshot(ctx context.Context, pool *pgxpool.Pool, userID int64) (*ProgressSnapshot, error) {
	var row ProgressSnapshot
	err := pool.QueryRow(ctx, `
		SELECT game_state_json, updated_at, COALESCE(revision, 1)
		FROM user_progress
		WHERE user_id = $1
	`, userID).Scan(&row.State, &row.UpdatedAt, &row.Revision)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &row, nil
}

// UpsertProgressSnapshot 按 updatedAt last-write-wins 写入快照。
// conflict=true 表示云端更新，未覆盖，返回当前云端行。
func UpsertProgressSnapshot(
	ctx context.Context,
	pool *pgxpool.Pool,
	userID int64,
	state json.RawMessage,
	clientUpdatedAt time.Time,
) (row *ProgressSnapshot, conflict bool, err error) {
	var out ProgressSnapshot
	err = pool.QueryRow(ctx, `
		INSERT INTO user_progress (user_id, game_state_json, updated_at, revision)
		VALUES ($1, $2::jsonb, $3, 1)
		ON CONFLICT (user_id) DO UPDATE SET
			game_state_json = EXCLUDED.game_state_json,
			updated_at = EXCLUDED.updated_at,
			revision = user_progress.revision + 1
		WHERE user_progress.updated_at <= EXCLUDED.updated_at
		RETURNING game_state_json, updated_at, revision
	`, userID, []byte(state), clientUpdatedAt).Scan(&out.State, &out.UpdatedAt, &out.Revision)
	if errors.Is(err, pgx.ErrNoRows) {
		// ON CONFLICT 的 WHERE 未满足：云端更新，未覆盖
		current, getErr := GetProgressSnapshot(ctx, pool, userID)
		if getErr != nil {
			return nil, false, getErr
		}
		return current, true, nil
	}
	if err != nil {
		return nil, false, err
	}
	return &out, false, nil
}
