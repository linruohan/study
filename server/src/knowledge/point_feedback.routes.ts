import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { requireAdmin } from '../auth/auth.hooks.js';
import { invalidateKnowledgeBundleCache } from './knowledge.routes.js';
import { HttpError } from '../http/errors.js';
import * as repository from './point_feedback.repository.js';

/// 审核通过后的积分额度由服务端定值，不再信任客户端传参。
const CORRECTION_REWARD_POINTS = 5;

const pointRefSchema = z.object({
  conceptId: z.string().trim().min(1),
  ageBandId: z.string().trim().min(1),
  degreeId: z.string().trim().min(1),
  position: z.coerce.number().int().min(1),
});

const createCommentSchema = pointRefSchema.extend({
  deviceId: z.string().uuid(),
  body: z.string().trim().min(1).max(2000),
});

const createCorrectionSchema = pointRefSchema.extend({
  deviceId: z.string().uuid(),
  body: z.string().trim().min(1).max(4000),
  suggestedText: z.string().trim().max(4000).nullable().optional(),
});

const reviewSchema = z.object({
  correctionId: z.string().uuid(),
  approve: z.boolean(),
  points: z.number().int().min(0).max(1000).optional().default(0),
});

function parseOrThrow<S extends z.ZodTypeAny>(schema: S, data: unknown): z.infer<S> {
  const result = schema.safeParse(data);
  if (!result.success) {
    const issue = result.error.issues[0];
    const where = issue?.path.join('.') || 'body';
    throw new HttpError(400, 'invalid_request', issue ? `${where}: ${issue.message}` : '请求参数不对');
  }
  return result.data;
}

/// 知识点互动：评论、纠错提交与审核（审核通过可发放积分）。
export async function pointFeedbackRoutes(app: FastifyInstance): Promise<void> {
  app.get('/api/knowledge/points/comments', async (request) => {
    const q = pointRefSchema.extend({ limit: z.coerce.number().int().min(1).max(200).optional(), offset: z.coerce.number().int().min(0).optional() }).safeParse(request.query);
    if (!q.success) throw new HttpError(400, 'invalid_request', '请求参数不对');
    const comments = await repository.listComments(q.data, q.data.limit, q.data.offset);
    return { comments };
  });

  app.post('/api/knowledge/points/comments', async (request) => {
    const input = parseOrThrow(createCommentSchema, request.body);
    const comment = await repository.createComment(
      { conceptId: input.conceptId, ageBandId: input.ageBandId, degreeId: input.degreeId, position: input.position },
      input.deviceId,
      input.body,
    );
    return { comment };
  });

  app.get('/api/knowledge/points/corrections', async (request) => {
    const q = pointRefSchema.extend({ limit: z.coerce.number().int().min(1).max(200).optional(), offset: z.coerce.number().int().min(0).optional() }).safeParse(request.query);
    if (!q.success) throw new HttpError(400, 'invalid_request', '请求参数不对');
    const corrections = await repository.listCorrections(q.data, q.data.limit, q.data.offset);
    return { corrections };
  });

  app.post('/api/knowledge/points/corrections', async (request) => {
    const input = parseOrThrow(createCorrectionSchema, request.body);
    const correction = await repository.createCorrection(
      { conceptId: input.conceptId, ageBandId: input.ageBandId, degreeId: input.degreeId, position: input.position },
      input.deviceId,
      input.body,
      input.suggestedText ?? null,
    );
    return { correction };
  });


  app.get('/api/knowledge/points/corrections/pending', async (request) => {
    const parsed = z.object({ limit: z.coerce.number().int().min(1).max(200).optional(), offset: z.coerce.number().int().min(0).optional() }).safeParse(request.query);
    if (!parsed.success) throw new HttpError(400, 'invalid_request', '请求参数不对');
    const corrections = await repository.listPendingCorrections(parsed.data.limit, parsed.data.offset);
    return { corrections };
  });

  app.post('/api/knowledge/points/corrections/review', { preHandler: requireAdmin }, async (request) => {
    const input = parseOrThrow(reviewSchema, request.body);
    // 审核人身份取自登录的管理员，不再信任请求体里自报的 deviceId。
    const reviewer = request.authUser!;
    const correction = await repository.reviewCorrection(
      input.correctionId,
      reviewer.id,
      input.approve,
      input.approve ? CORRECTION_REWARD_POINTS : 0,
    );
    // 审核通过会把纠错写回知识点正文，知识包内容变了，让缓存失效。
    invalidateKnowledgeBundleCache();
    return { correction };
  });

  app.get('/api/knowledge/points/credits', async (request) => {
    const parsed = z.object({ deviceId: z.string().uuid(), limit: z.coerce.number().int().min(1).max(200).optional(), offset: z.coerce.number().int().min(0).optional() }).safeParse(request.query);
    if (!parsed.success) {
      throw new HttpError(400, 'invalid_request', 'deviceId: 必须是合法 uuid');
    }
    return repository.listCredits(parsed.data.deviceId, parsed.data.limit, parsed.data.offset);
  });

}
