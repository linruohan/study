import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { HttpError } from '../http/errors.js';
import { createCategory, loadKnowledgeBundle } from './knowledge.repository.js';

const createCategorySchema = z.object({
  id: z.string().trim().min(1).max(64),
  parentId: z.string().trim().min(1).max(64).nullable().optional(),
  name: z.string().trim().min(1).max(60),
  question: z.string().trim().max(200).optional().default(''),
  ancient: z.string().trim().max(120).optional().default(''),
  modern: z.string().trim().max(200).optional().default(''),
  glyph: z.string().trim().max(8).optional().default('类'),
  color: z.string().trim().regex(/^#[0-9A-Fa-f]{6}$/).optional().default('#7A6A54'),
});

/// 知识库接口：返回全部内容；支持在九大基类下创建可嵌套子类型。
export async function knowledgeRoutes(app: FastifyInstance): Promise<void> {
  app.get('/api/knowledge', async (_request, reply) => {
    const bundle = await loadKnowledgeBundle();
    return reply.header('cache-control', 'no-store').send(bundle);
  });

  app.post('/api/knowledge/categories', async (request) => {
    const parsed = createCategorySchema.safeParse(request.body);
    if (!parsed.success) {
      const issue = parsed.error.issues[0];
      throw new HttpError(400, 'invalid_request', issue ? `${issue.path.join('.') || 'body'}: ${issue.message}` : '请求参数不对');
    }
    try {
      const category = await createCategory(parsed.data);
      return { category };
    } catch (error) {
      const e = error as { statusCode?: number; code?: string };
      if (e.statusCode === 503 || e.code === 'migration_required' || (error as { code?: string }).code === '42703') {
        throw new HttpError(503, 'migration_required', '子类型功能尚未启用，请先执行数据库迁移');
      }
      if (e.statusCode === 404) {
        throw new HttpError(404, 'not_found', '父分类不存在');
      }
      if (e.statusCode === 409) {
        throw new HttpError(409, 'conflict', '分类 id 已存在');
      }
      if ((error as { code?: string }).code === '23505') {
        throw new HttpError(409, 'conflict', '分类 id 已存在');
      }
      throw error;
    }
  });
}
