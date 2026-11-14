-- 加固批次：补索引与数据一致性约束。
-- 1) 自建方案按 owner 查询（列表页 WHERE is_builtin OR owner_user_id）。
CREATE INDEX IF NOT EXISTS idx_plan_schemes_owner_user_id
  ON plan_schemes (owner_user_id);

-- 2) 过期会话清理（登录时顺带 DELETE WHERE expires_at < now()）。
CREATE INDEX IF NOT EXISTS idx_auth_sessions_expires_at
  ON auth_sessions (expires_at);

-- 3) 同一用户同时只允许一条待审学位申请：数据库层兜底，防并发绕过。
CREATE UNIQUE INDEX IF NOT EXISTS uq_degree_applications_one_pending
  ON degree_applications (user_id) WHERE status = 'pending';
