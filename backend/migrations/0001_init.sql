-- 塑身工坊初始表结构

-- 用户账号（软删支持：deleted_at 非空 = 已注销，30 天后物理清除）
CREATE TABLE IF NOT EXISTS users (
    id          BIGSERIAL PRIMARY KEY,
    email       TEXT NOT NULL UNIQUE,
    nickname    TEXT NOT NULL,
    pass_hash   TEXT NOT NULL,
    avatar_url  TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at  TIMESTAMPTZ
);

-- 进度快照（对齐 App 端 GameState.toJson）
CREATE TABLE IF NOT EXISTS user_progress (
    user_id        BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    game_state_json JSONB NOT NULL,
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 行为流水（记录餐食/锻炼/战绩，支持增量同步与统计）
CREATE TABLE IF NOT EXISTS progress_events (
    id            BIGSERIAL PRIMARY KEY,
    user_id       BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type          TEXT NOT NULL,              -- meal / exercise / battle / weight
    payload_json  JSONB NOT NULL DEFAULT '{}',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_events_user_time
    ON progress_events (user_id, created_at);

-- 食物识别纠错反馈（M3 使用）
CREATE TABLE IF NOT EXISTS food_feedback (
    id           BIGSERIAL PRIMARY KEY,
    user_id      BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    image_url    TEXT,
    ocr_result   JSONB,
    user_cal     INT,
    status       TEXT NOT NULL DEFAULT 'pending',
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
