import type { FastifyInstance, FastifyRequest } from 'fastify';
import { z } from 'zod';
import { requireAuth } from '../auth/auth.hooks.js';
import { HttpError } from '../http/errors.js';
import {
  clonePlanScheme,
  createPlanScheme,
  deletePlanScheme,
  getPlanScheme,
  listPlanSchemes,
  updatePlanScheme,
} from './plan_scheme.repository.js';

/// 自建方案的阶段：与内置方案的七个阶段一致。
const stageSchema = z.enum([
  'mengxue',
  'primary',
  'junior',
  'senior',
  'college',
  'graduate',
  'master',
]);

/// 条目：知识内容必填，学习程度与概念关联可选。
const itemSchema = z.object({
  content: z.string().trim().min(1).max(2000),
  expectedLevel: z.string().trim().max(2000).optional().default(''),
  conceptId: z.string().trim().max(64).nullable().optional(),
});

/// 维度：名称 + 条目列表。
const dimensionSchema = z.object({
  name: z.string().trim().min(1).max(120),
  items: z.array(itemSchema).max(100),
});

/// 创建/更新方案的载荷。
const upsertSchemeSchema = z.object({
  name: z.string().trim().min(1).max(120),
  stage: stageSchema,
  description: z.string().trim().max(2000).default(''),
  dimensions: z.array(dimensionSchema).max(50),
});

function parseBody<S extends z.ZodTypeAny>(schema: S, body: unknown): z.output<S> {
  const parsed = schema.safeParse(body);
  if (!parsed.success) {
    const issue = parsed.error.issues[0];
    throw new HttpError(
      400,
      'invalid_request',
      issue ? `${issue.path.join('.') || 'body'}: ${issue.message}` : '请求参数不对',
    );
  }
  return parsed.data;
}

/// GET 接口的可选登录：带了 Bearer token 就解析，没带或无效都按匿名处理。
async function optionalAuth(request: FastifyRequest): Promise<string | null> {
  if (!request.headers.authorization) {
    return null;
  }
  try {
    const user = await requireAuth(request);
    return user.id;
  } catch {
    return null;
  }
}

/// 学习计划方案接口：内置方案人人可读，自建方案仅创建者可见可改。
export async function planSchemeRoutes(app: FastifyInstance): Promise<void> {
  // 方案列表：内置 + 本人自建。匿名也能看内置方案。
  app.get('/api/plan-schemes', async (request, reply) => {
    const userId = await optionalAuth(request);
    const schemes = await listPlanSchemes(userId);
    return reply.header('cache-control', 'no-store').send({ schemes });
  });

  // 方案详情：内置公开，自建仅 owner（他人访问按 404 处理，不暴露存在性）。
  app.get('/api/plan-schemes/:id', async (request, reply) => {
    const { id } = request.params as { id: string };
    const userId = await optionalAuth(request);
    const scheme = await getPlanScheme(id, userId);
    return reply.header('cache-control', 'no-store').send({ scheme });
  });

  // 创建自建方案。
  app.post('/api/plan-schemes', { preHandler: requireAuth }, async (request) => {
    const user = await requireAuth(request);
    const input = parseBody(upsertSchemeSchema, request.body);
    const scheme = await createPlanScheme(user.id, {
      name: input.name,
      stage: input.stage,
      description: input.description,
      dimensions: input.dimensions,
    });
    return { scheme };
  });

  // 更新自建方案（整体替换维度/条目）。
  app.put('/api/plan-schemes/:id', { preHandler: requireAuth }, async (request) => {
    const user = await requireAuth(request);
    const { id } = request.params as { id: string };
    const input = parseBody(upsertSchemeSchema, request.body);
    const scheme = await updatePlanScheme(id, user.id, {
      name: input.name,
      stage: input.stage,
      description: input.description,
      dimensions: input.dimensions,
    });
    return { scheme };
  });

  // 删除自建方案；内置方案不可删。
  app.delete('/api/plan-schemes/:id', { preHandler: requireAuth }, async (request) => {
    const user = await requireAuth(request);
    const { id } = request.params as { id: string };
    await deletePlanScheme(id, user.id);
    return { ok: true };
  });

  // 复制方案为本人自建。
  app.post('/api/plan-schemes/:id/clone', { preHandler: requireAuth }, async (request) => {
    const user = await requireAuth(request);
    const { id } = request.params as { id: string };
    const scheme = await clonePlanScheme(id, user.id);
    return { scheme };
  });
}
