-- 进度快照增加 revision，供 App 做 last-write-wins 冲突判断
-- （0001 已建 user_progress；本迁移兼容老库）

ALTER TABLE user_progress
    ADD COLUMN IF NOT EXISTS revision BIGINT NOT NULL DEFAULT 1;

-- 保证 updated_at 有默认值（老库已有则跳过）
ALTER TABLE user_progress
    ALTER COLUMN updated_at SET DEFAULT NOW();
