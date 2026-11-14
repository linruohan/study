import type { FastifyReply, FastifyRequest } from 'fastify';
import { HttpError } from '../http/errors.js';
import { userForToken, type AuthUser } from './auth.repository.js';

/// 从 Authorization: Bearer <token> 里解析用户；失败按 401/403 报错。
async function parseBearer(request: FastifyRequest): Promise<AuthUser | null> {
  const header = request.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    return null;
  }
  const token = header.slice('Bearer '.length).trim();
  if (!token) {
    return null;
  }
  return userForToken(token);
}

/// 要求已登录；把当前用户挂到 request.authUser 供路由读取。
export async function requireAuth(request: FastifyRequest): Promise<AuthUser> {
  const user = await parseBearer(request);
  if (!user) {
    throw new HttpError(401, 'unauthorized', '请先登录');
  }
  request.authUser = user;
  return user;
}

/// 要求管理员；普通用户返回 403，未登录返回 401。
export async function requireAdmin(request: FastifyRequest): Promise<AuthUser> {
  const user = await requireAuth(request);
  if (user.role !== 'admin') {
    throw new HttpError(403, 'forbidden', '只有管理员可以修改知识内容');
  }
  return user;
}

declare module 'fastify' {
  interface FastifyRequest {
    authUser?: AuthUser;
  }
}
