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

const listQuerySchema = z.object({
  limit: z.coerce.number().int().min(1).max(200).optional(),
  offset: z.coerce.number().int().min(0).optional(),
});

const idParamsSchema = z.object({
  id: z.string().uuid('用户 id 不是合法的 UUID'),
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
    const parsed = listQuerySchema.safeParse(request.query);
    if (!parsed.success) {
      throw new HttpError(400, 'invalid_request', 'limit/offset 需要是合法数字');
    }
    const users = await listUsers(parsed.data.limit, parsed.data.offset);
    return { users };
  });

  app.patch('/api/users/:id/role', { preHandler: requireAdmin }, async (request) => {
    const parsedParams = idParamsSchema.safeParse(request.params);
    const parsed = roleSchema.safeParse(request.body);
    if (!parsedParams.success || !parsed.success) {
      throw new HttpError(400, 'invalid_request', '参数不对：id 需是 UUID，role 必须是 user 或 admin');
    }
    // 不允许管理员修改自己的角色，避免最后一个管理员把自己降级后系统无人管理。
    const admin = request.authUser!;
    if (parsedParams.data.id === admin.id) {
      throw new HttpError(403, 'forbidden', '不能修改自己的角色');
    }
    await setUserRole(parsedParams.data.id, parsed.data.role);
    return { ok: true };
  });

  app.post('/api/users/:id/reset-password', { preHandler: requireAdmin }, async (request) => {
    const parsedParams = idParamsSchema.safeParse(request.params);
    if (!parsedParams.success) {
      throw new HttpError(400, 'invalid_request', '用户 id 不是合法的 UUID');
    }
    const tempPassword = await adminResetPassword(parsedParams.data.id);
    return { tempPassword };
  });
}
