import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { HttpError } from '../http/errors.js';
import * as repository from './point_feedback.repository.js';

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
  reviewerDeviceId: z.string().uuid(),
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
    const ref = parseOrThrow(pointRefSchema, request.query);
    const comments = await repository.listComments(ref);
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
    const ref = parseOrThrow(pointRefSchema, request.query);
    const corrections = await repository.listCorrections(ref);
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

  app.post('/api/knowledge/points/corrections/review', async (request) => {
    const input = parseOrThrow(reviewSchema, request.body);
    const correction = await repository.reviewCorrection(
      input.correctionId,
      input.reviewerDeviceId,
      input.approve,
      input.approve ? (input.points ?? 0) : 0,
    );
    return { correction };
  });
}