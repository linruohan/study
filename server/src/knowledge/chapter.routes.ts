import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { requireAdmin } from '../auth/auth.hooks.js';
import { HttpError } from '../http/errors.js';
import { invalidateKnowledgeBundleCache } from './knowledge.routes.js';
import * as repository from './chapter.repository.js';

const refSchema = z.object({
  conceptId: z.string().trim().min(1),
  ageBandId: z.string().trim().min(1),
  degreeId: z.string().trim().min(1),
  pointPosition: z.coerce.number().int().min(1),
});

const createSchema = refSchema.extend({
  title: z.string().trim().min(1).max(200),
  content: z.string().trim().max(8000).nullable().optional(),
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

/// 知识点章节：最基础的知识单元。
export async function chapterRoutes(app: FastifyInstance): Promise<void> {
  app.get('/api/knowledge/points/chapters', async (request) => {
    const ref = parseOrThrow(refSchema, request.query);
    const chapters = await repository.listChapters(ref);
    return { chapters };
  });

  app.post('/api/knowledge/points/chapters', { preHandler: requireAdmin }, async (request) => {
    const input = parseOrThrow(createSchema, request.body);
    const chapter = await repository.addChapter(
      { conceptId: input.conceptId, ageBandId: input.ageBandId, degreeId: input.degreeId, pointPosition: input.pointPosition },
      { title: input.title, content: input.content ?? null },
    );
    invalidateKnowledgeBundleCache();
    return { chapter };
  });

  const updateSchema = refSchema.extend({
    chapterPosition: z.coerce.number().int().min(1),
    title: z.string().trim().min(1).max(200),
    content: z.string().trim().max(8000).nullable().optional(),
  });
  const deleteSchema = refSchema.extend({
    chapterPosition: z.coerce.number().int().min(1),
  });

  app.put('/api/knowledge/points/chapters', { preHandler: requireAdmin }, async (request) => {
    const input = parseOrThrow(updateSchema, request.body);
    const chapter = await repository.updateChapter(
      { conceptId: input.conceptId, ageBandId: input.ageBandId, degreeId: input.degreeId, pointPosition: input.pointPosition },
      input.chapterPosition,
      { title: input.title, content: input.content ?? null },
    );
    invalidateKnowledgeBundleCache();
    return { chapter };
  });

  app.delete('/api/knowledge/points/chapters', { preHandler: requireAdmin }, async (request) => {
    const input = parseOrThrow(deleteSchema, request.query);
    await repository.deleteChapter(
      { conceptId: input.conceptId, ageBandId: input.ageBandId, degreeId: input.degreeId, pointPosition: input.pointPosition },
      input.chapterPosition,
    );
    invalidateKnowledgeBundleCache();
    return { ok: true };
  });
}