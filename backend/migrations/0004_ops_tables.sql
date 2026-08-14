-- 运营表：把 GameState blob 拆成可查询行（幂等，API 启动时执行）
-- docker-entrypoint-initdb 只挂 0001；本文件及之后一律靠 migrate.go。

CREATE TABLE IF NOT EXISTS schema_migrations (
    filename   TEXT PRIMARY KEY,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 1. 建档身体与偏好（1:1 users）
CREATE TABLE IF NOT EXISTS user_profiles (
    user_id            BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    nickname           TEXT,
    avatar             TEXT,
    age                INT,
    gender             TEXT,
    height_cm          NUMERIC(6,2),
    weight_kg          NUMERIC(6,2),
    target_weight_kg   NUMERIC(6,2),
    bmi                NUMERIC(6,2),
    sleep_type         TEXT,
    work_type          TEXT,
    exercise_time      TEXT,
    character_style    TEXT,
    difficulty         TEXT,
    fitness_level      TEXT,
    pushup_count       INT,
    run_duration_min   INT,
    weekly_freq        INT,
    visual_theme       TEXT,
    sculpt_line        TEXT,
    knee_issue         BOOLEAN NOT NULL DEFAULT false,
    waist_issue        BOOLEAN NOT NULL DEFAULT false,
    target_cal         INT,
    calorie_floor      INT,
    streak             INT NOT NULL DEFAULT 0,
    last_seen_at       TIMESTAMPTZ,
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. 体重/腰围时间序列（按日去重）
CREATE TABLE IF NOT EXISTS body_metrics (
    id           BIGSERIAL PRIMARY KEY,
    user_id      BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    recorded_on  DATE NOT NULL,
    weight_kg    NUMERIC(6,2),
    waist_cm     NUMERIC(6,2),
    source       TEXT NOT NULL DEFAULT 'app',
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, recorded_on)
);
CREATE INDEX IF NOT EXISTS idx_body_metrics_user_day
    ON body_metrics (user_id, recorded_on DESC);

-- 3. 锻炼课
CREATE TABLE IF NOT EXISTS exercise_sessions (
    id               BIGSERIAL PRIMARY KEY,
    user_id          BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    started_at       TIMESTAMPTZ,
    ended_at         TIMESTAMPTZ,
    lesson_id        TEXT,
    lesson_name      TEXT,
    mode             TEXT,
    moves            JSONB NOT NULL DEFAULT '[]',
    total_reps       INT,
    quality_avg      NUMERIC(6,2),
    calories_burned  INT,
    damage_dealt     INT,
    feel             TEXT,
    settled          BOOLEAN NOT NULL DEFAULT false,
    client_event_id  TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_exercise_sessions_client
    ON exercise_sessions (user_id, client_event_id)
    WHERE client_event_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_exercise_sessions_user_time
    ON exercise_sessions (user_id, COALESCE(ended_at, started_at, created_at) DESC);

-- 4. 饮食
CREATE TABLE IF NOT EXISTS meal_logs (
    id               BIGSERIAL PRIMARY KEY,
    user_id          BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    eaten_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    name             TEXT NOT NULL,
    grams            INT,
    calories         INT,
    meal_slot        TEXT,
    source           TEXT NOT NULL DEFAULT 'manual',
    client_event_id  TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_meal_logs_client
    ON meal_logs (user_id, client_event_id)
    WHERE client_event_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_meal_logs_user_time
    ON meal_logs (user_id, eaten_at DESC);

-- 5. 桌面雕塑（1:1）
CREATE TABLE IF NOT EXISTS sculpt_progress (
    user_id          BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    stage            INT NOT NULL DEFAULT 0 CHECK (stage BETWEEN 0 AND 7),
    progress         NUMERIC(6,4) NOT NULL DEFAULT 0,
    line             TEXT NOT NULL DEFAULT 'venus',
    sessions_count   INT NOT NULL DEFAULT 0,
    last_settled_at  TIMESTAMPTZ,
    maintenance      TEXT NOT NULL DEFAULT 'none',
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. 运营可配（key / jsonb value）
CREATE TABLE IF NOT EXISTS app_settings (
    key         TEXT PRIMARY KEY,
    value       JSONB NOT NULL,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO app_settings (key, value) VALUES
    ('calorie_floor', '1500'::jsonb),
    ('max_daily_deficit', '750'::jsonb),
    ('coach_enabled', 'true'::jsonb),
    ('food_recognize_enabled', 'true'::jsonb),
    ('default_visual_theme', '"forge"'::jsonb),
    ('sculpt_session_thresholds', '[3,10,21,30]'::jsonb)
ON CONFLICT (key) DO NOTHING;

-- 7. 管理操作审计
CREATE TABLE IF NOT EXISTS admin_audit_log (
    id               BIGSERIAL PRIMARY KEY,
    actor_id         BIGINT,
    actor_username   TEXT,
    action           TEXT NOT NULL,
    target_user_id   BIGINT,
    before_json      JSONB,
    after_json       JSONB,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_admin_audit_time
    ON admin_audit_log (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_audit_target
    ON admin_audit_log (target_user_id, created_at DESC);

-- 流水类型扩展：已有 progress_events；补索引便于按 type 过滤
CREATE INDEX IF NOT EXISTS idx_events_user_type_time
    ON progress_events (user_id, type, created_at DESC);
