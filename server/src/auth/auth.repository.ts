import { pool } from '../db.js';
import { HttpError } from '../http/errors.js';
import { hashPassword, newSessionToken, tokenDigest, verifyPassword } from './auth.service.js';

export interface AuthUser {
  id: string;
  username: string;
  role: 'user' | 'admin';
  mustChangePassword: boolean;
}

interface UserRow {
  id: string;
  username: string;
  password_hash: string;
  role: 'user' | 'admin';
  must_change_password: boolean;
}

const SESSION_TTL_MS = 30 * 24 * 60 * 60 * 1000; // 30 天

function toAuthUser(row: UserRow): AuthUser {
  return {
    id: row.id,
    username: row.username,
    role: row.role,
    mustChangePassword: row.must_change_password,
  };
}

/// 启动时确保内置 admin 账号存在；已存在则不动（不重置密码）。
export async function ensureAdminUser(): Promise<void> {
  const existing = await pool.query('SELECT 1 FROM users WHERE username = $1', ['admin']);
  if (existing.rowCount && existing.rowCount > 0) {
    return;
  }
  await pool.query(
    `INSERT INTO users (username, password_hash, role, must_change_password)
     VALUES ($1, $2, 'admin', true)`,
    ['admin', hashPassword('admin')],
  );
}

export async function login(username: string, password: string): Promise<{ token: string; user: AuthUser }> {
  const result = await pool.query<UserRow>(
    'SELECT id, username, password_hash, role, must_change_password FROM users WHERE username = $1',
    [username],
  );
  const row = result.rows[0];
  if (!row || !verifyPassword(password, row.password_hash)) {
    throw new HttpError(401, 'invalid_credentials', '用户名或密码不对');
  }
  const token = await createSession(row.id);
  return { token, user: toAuthUser(row) };
}

async function createSession(userId: string): Promise<string> {
  // 生成原始 token 只在响应里出现一次，库里只留摘要。
  const token = newSessionToken();
  await pool.query(
    `INSERT INTO auth_sessions (token_hash, user_id, expires_at)
     VALUES ($1, $2, now() + interval '${Math.floor(SESSION_TTL_MS / 86400000)} days')`,
    [tokenDigest(token), userId],
  );
  return token;
}

/// 按 token 摘要找用户；过期或不存在返回 null。
export async function userForToken(token: string): Promise<AuthUser | null> {
  const result = await pool.query<UserRow>(
    `SELECT u.id, u.username, u.password_hash, u.role, u.must_change_password
       FROM auth_sessions s
       JOIN users u ON u.id = s.user_id
      WHERE s.token_hash = $1 AND s.expires_at > now()`,
    [tokenDigest(token)],
  );
  const row = result.rows[0];
  return row ? toAuthUser(row) : null;
}

export async function logout(token: string): Promise<void> {
  await pool.query('DELETE FROM auth_sessions WHERE token_hash = $1', [tokenDigest(token)]);
}

export async function changePassword(
  userId: string,
  oldPassword: string,
  newPassword: string,
): Promise<AuthUser> {
  const result = await pool.query<UserRow>(
    'SELECT id, username, password_hash, role, must_change_password FROM users WHERE id = $1',
    [userId],
  );
  const row = result.rows[0];
  if (!row) {
    throw new HttpError(404, 'not_found', '用户不存在');
  }
  if (!verifyPassword(oldPassword, row.password_hash)) {
    throw new HttpError(401, 'invalid_credentials', '原密码不对');
  }
  const updated = await pool.query<UserRow>(
    `UPDATE users
        SET password_hash = $2, must_change_password = false, updated_at = now()
      WHERE id = $1
    RETURNING id, username, password_hash, role, must_change_password`,
    [userId, hashPassword(newPassword)],
  );
  return toAuthUser(updated.rows[0]);
}

/// 管理员重置他人密码：生成临时密码并要求下次登录修改。
export async function adminResetPassword(userId: string): Promise<string> {
  const temp = `study-${Math.random().toString(36).slice(2, 10)}`;
  const result = await pool.query(
    `UPDATE users
        SET password_hash = $2, must_change_password = true, updated_at = now()
      WHERE id = $1`,
    [userId, hashPassword(temp)],
  );
  if (!result.rowCount) {
    throw new HttpError(404, 'not_found', '用户不存在');
  }
  return temp;
}

export async function setUserRole(userId: string, role: 'user' | 'admin'): Promise<void> {
  const result = await pool.query('UPDATE users SET role = $2, updated_at = now() WHERE id = $1', [
    userId,
    role,
  ]);
  if (!result.rowCount) {
    throw new HttpError(404, 'not_found', '用户不存在');
  }
}

export async function listUsers(limit = 100, offset = 0): Promise<AuthUser[]> {
  const safeLimit = Math.min(Math.max(limit, 1), 200);
  const safeOffset = Math.max(offset, 0);
  const result = await pool.query<UserRow>(
    `SELECT id, username, password_hash, role, must_change_password
       FROM users
      ORDER BY created_at
      LIMIT $1 OFFSET $2`,
    [safeLimit, safeOffset],
  );
  return result.rows.map(toAuthUser);
}
