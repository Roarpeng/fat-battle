-- 管理后台：管理员账号 + LLM 配置（幂等，兼容已有老库）

-- 管理员账号
CREATE TABLE IF NOT EXISTS admin_users (
    id BIGSERIAL PRIMARY KEY,
    username TEXT NOT NULL UNIQUE,
    pass_hash TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'admin',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- LLM 服务配置（密钥只存服务器）
CREATE TABLE IF NOT EXISTS llm_configs (
    id BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL,               -- 配置名，如 "智谱 GLM 主服务"
    provider TEXT NOT NULL DEFAULT 'zhipu',
    base_url TEXT NOT NULL DEFAULT 'https://open.bigmodel.cn',
    api_key TEXT NOT NULL,            -- 只存服务器
    vision_model TEXT NOT NULL DEFAULT 'glm-4.6v-flash',
    text_model TEXT NOT NULL DEFAULT 'glm-4-flash',
    enabled BOOLEAN NOT NULL DEFAULT true,
    priority INT NOT NULL DEFAULT 0,
    remark TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 用户禁用标记（兼容老库：users 表已存在时仅加列）
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_disabled BOOLEAN NOT NULL DEFAULT false;
