import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { HttpError } from '../http/errors.js';
import {
  adminResetPassword,
  changePassword,
  listUsers,
  login,
  logout,
  setUserRole,
} from './auth.repository.js';
import { requireAdmin, requireAuth } from './auth.hooks.js';

const loginSchema = z.object({
  username: z.string().trim().min(1).max(60),
  password: z.string().min(1).max(200),
});

const changePasswordSchema = z.object({
  oldPassword: z.string().min(1).max(200),
  // 密码至少 8 位，避免默认口令一直用下去。
  newPassword: z.string().min(8).max(200),
});

const roleSchema = z.object({
  role: z.enum(['user', 'admin']),
});

/// 登录与会话接口；用户管理接口仅管理员可用。
export async function authRoutes(app: FastifyInstance): Promise<void> {
  app.post('/api/auth/login', async (request) => {
    const parsed = loginSchema.safeParse(request.body);
    if (!parsed.success) {
      const issue = parsed.error.issues[0];
      throw new HttpError(400, 'invalid_request', issue ? `${issue.path.join('.')}: ${issue.message}` : '请求参数不对');
    }
    const { token, user } = await login(parsed.data.username, parsed.data.password);
    return { token, user };
  });

  app.post('/api/auth/logout', { preHandler: requireAuth }, async (request) => {
    const header = request.headers.authorization;
    const token = header?.startsWith('Bearer ') ? header.slice('Bearer '.length).trim() : '';
    if (token) {
      await logout(token);
    }
    return { ok: true };
  });

  app.get('/api/auth/me', { preHandler: requireAuth }, async (request) => {
    return { user: request.authUser };
  });

  app.post('/api/auth/password', { preHandler: requireAuth }, async (request) => {
    const user = request.authUser!;
    const parsed = changePasswordSchema.safeParse(request.body);
    if (!parsed.success) {
      const issue = parsed.error.issues[0];
      throw new HttpError(400, 'invalid_request', issue ? `${issue.path.join('.')}: ${issue.message}` : '请求参数不对');
    }
    const updated = await changePassword(user.id, parsed.data.oldPassword, parsed.data.newPassword);
    return { user: updated };
  });

  app.get('/api/users', { preHandler: requireAdmin }, async (request) => {
    const query = request.query as { limit?: string; offset?: string };
    const users = await listUsers(
      query.limit ? Number.parseInt(query.limit, 10) : undefined,
      query.offset ? Number.parseInt(query.offset, 10) : undefined,
    );
    return { users };
  });

  app.patch('/api/users/:id/role', { preHandler: requireAdmin }, async (request) => {
    const { id } = request.params as { id: string };
    const parsed = roleSchema.safeParse(request.body);
    if (!parsed.success) {
      throw new HttpError(400, 'invalid_request', 'role 必须是 user 或 admin');
    }
    await setUserRole(id, parsed.data.role);
    return { ok: true };
  });

  app.post('/api/users/:id/reset-password', { preHandler: requireAdmin }, async (request) => {
    const { id } = request.params as { id: string };
    const tempPassword = await adminResetPassword(id);
    return { tempPassword };
  });
}
