import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { requireAdmin, requireAuth } from '../auth/auth.hooks.js';
import { HttpError } from '../http/errors.js';
import {
  listApplications,
  myApplications,
  myDegree,
  REALMS,
  reviewApplication,
  submitApplication,
} from './degree.repository.js';

const applySchema = z.object({
  targetRealm: z.enum(REALMS),
  // 证据链：客户端可带学习广度/深度的自述；服务端后续可复核。
  evidence: z.record(z.unknown()).optional().default({}),
});

const reviewSchema = z.object({
  approve: z.boolean(),
});

const statusSchema = z
  .enum(['pending', 'approved', 'rejected', 'all'])
  .default('pending');

const listQuerySchema = z.object({
  limit: z.coerce.number().int().min(1).max(200).optional(),
  offset: z.coerce.number().int().min(0).optional(),
});

/// 九境三阶：查看自己的境界、提交学位申请；审核仅管理员。
export async function degreeRoutes(app: FastifyInstance): Promise<void> {
  app.get('/api/degree', { preHandler: requireAuth }, async (request) => {
    return { degree: await myDegree(request.authUser!.id) };
  });

  app.post('/api/degree/applications', { preHandler: requireAuth }, async (request) => {
    const parsed = applySchema.safeParse(request.body);
    if (!parsed.success) {
      const issue = parsed.error.issues[0];
      throw new HttpError(400, 'invalid_request', issue ? `${issue.path.join('.')}: ${issue.message}` : '请求参数不对');
    }
    const application = await submitApplication(
      request.authUser!.id,
      parsed.data.targetRealm,
      parsed.data.evidence,
    );
    return { application };
  });

  app.get('/api/degree/applications/mine', { preHandler: requireAuth }, async (request) => {
    const parsed = listQuerySchema.safeParse(request.query);
    if (!parsed.success) {
      throw new HttpError(400, 'invalid_request', 'limit/offset 需要是合法数字');
    }
    const applications = await myApplications(
      request.authUser!.id,
      parsed.data.limit,
      parsed.data.offset,
    );
    return { applications };
  });

  app.get('/api/degree/applications', { preHandler: requireAdmin }, async (request) => {
    const parsed = listQuerySchema.safeParse(request.query);
    const status = statusSchema.safeParse((request.query as { status?: string }).status);
    if (!parsed.success) {
      throw new HttpError(400, 'invalid_request', 'limit/offset 需要是合法数字');
    }
    if (!status.success) {
      throw new HttpError(400, 'invalid_request', 'status 必须是 pending/approved/rejected/all');
    }
    const applications = await listApplications(status.data, parsed.data.limit, parsed.data.offset);
    return { applications };
  });

  app.post('/api/degree/applications/:id/review', { preHandler: requireAdmin }, async (request) => {
    const { id } = request.params as { id: string };
    const parsed = reviewSchema.safeParse(request.body);
    if (!parsed.success) {
      throw new HttpError(400, 'invalid_request', 'approve 必须是布尔值');
    }
    const application = await reviewApplication(id, request.authUser!.id, parsed.data.approve);
    return { application };
  });
}
