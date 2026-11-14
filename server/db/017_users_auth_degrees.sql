-- 用户登录与权限：普通用户只读，管理员可写一切。
-- 同时落九境三阶的学位表与学位申请表（证据链审核后提境界）。

-- 用户表：密码只存 scrypt 哈希，绝不明文。
CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  username text NOT NULL UNIQUE,
  password_hash text NOT NULL,
  role text NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  -- 内置管理员 admin/admin 首次登录必须改密。
  must_change_password boolean NOT NULL DEFAULT false,
  device_id uuid REFERENCES devices (id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- 会话表：存 token 摘要（sha256），不存原始 token。
CREATE TABLE IF NOT EXISTS auth_sessions (
  token_hash text PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL
);
CREATE INDEX IF NOT EXISTS auth_sessions_user_idx ON auth_sessions (user_id);

-- 学位表：用户 ↔ 当前境界（九境三阶）。
CREATE TABLE IF NOT EXISTS user_degrees (
  user_id uuid PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
  realm text NOT NULL CHECK (realm IN ('none','shi','gou','tong','bian','chuang','li','hua','zong','dao')),
  stage text NOT NULL CHECK (stage IN ('early','middle','late')),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- 学位申请表：用户按学习广度/深度提交证据链，管理员审核通过后提升境界。
CREATE TABLE IF NOT EXISTS degree_applications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  target_realm text NOT NULL CHECK (target_realm IN ('shi','gou','tong','bian','chuang','li','hua','zong','dao')),
  evidence jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  reviewer_id uuid REFERENCES users (id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  reviewed_at timestamptz
);
CREATE INDEX IF NOT EXISTS degree_applications_status_idx
  ON degree_applications (status, created_at DESC);

COMMENT ON TABLE users IS '用户账号：普通用户只读，admin 角色可写一切知识内容';
COMMENT ON TABLE auth_sessions IS '登录会话：token 只存 sha256 摘要';
COMMENT ON TABLE user_degrees IS '九境三阶：用户当前境界（none 表示未入门）';
COMMENT ON TABLE degree_applications IS '学位申请：证据链由服务端按学习广度/depth 汇总，管理员审核';
