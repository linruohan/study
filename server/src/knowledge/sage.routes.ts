import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { HttpError } from '../http/errors.js';
import * as repository from './sage.repository.js';

/// 设备 id 放在路径里，必须是 UUID。
const deviceParamsSchema = z.object({
  deviceId: z.string().uuid('设备 id 不是合法的 UUID'),
});

/// 智者名：提交知识时显示的创建者名。
const sageNameSchema = z.object({
  name: z.string().trim().min(1, '名字不能为空').max(40, '名字太长了'),
});

/// 贡献输入：kind 决定是新建知识还是补充知识点。
const contributionSchema = z
  .object({
    kind: z.enum(['knowledge', 'point']),
    domainId: z.string().trim().min(1),
    ageBandId: z.string().trim().min(1),
    degreeId: z.string().trim().min(1),
    conceptId: z.string().trim().min(1).nullable().optional(),
    position: z.number().int().min(1).nullable().optional(),
    topic: z.string().trim().min(1, '知识点内容不能为空').max(120),
    doing: z.string().trim().max(500).nullable().optional(),
    note: z.string().trim().max(2000).nullable().optional(),
  })
  .transform((value) => ({
    kind: value.kind,
    domainId: value.domainId,
    ageBandId: value.ageBandId,
    degreeId: value.degreeId,
    conceptId: value.conceptId ?? null,
    position: value.position ?? null,
    topic: value.topic,
    doing: value.doing ?? null,
    note: value.note ?? null,
  }));

/// 校验并返回数据；不通过就转成 400。
function parseOrThrow<S extends z.ZodTypeAny>(
  schema: S,
  data: unknown,
): z.infer<S> {
  const result = schema.safeParse(data);
  if (!result.success) {
    const issue = result.error.issues[0];
    const where = issue?.path.join('.') || 'body';
    throw new HttpError(
      400,
      'invalid_request',
      issue ? `${where}：${issue.message}` : '请求参数不对',
    );
  }
  return result.data;
}

/// 智者接口：填名字、看自己的贡献、提交知识或知识点。
export async function sageRoutes(app: FastifyInstance): Promise<void> {
  app.get('/api/devices/:deviceId/sage', async (request) => {
    const { deviceId } = parseOrThrow(deviceParamsSchema, request.params);
    const name = await repository.loadSageName(deviceId);
    const contributions = await repository.listContributions(deviceId);
    return { name, contributions };
  });

  app.put('/api/devices/:deviceId/sage', async (request) => {
    const { deviceId } = parseOrThrow(deviceParamsSchema, request.params);
    const { name } = parseOrThrow(sageNameSchema, request.body);
    return { name: await repository.saveSageName(deviceId, name) };
  });

  app.post('/api/devices/:deviceId/sage/contributions', async (request) => {
    const { deviceId } = parseOrThrow(deviceParamsSchema, request.params);
    const input = parseOrThrow(contributionSchema, request.body);
    const contribution = await repository.createContribution(deviceId, input);
    return { contribution };
  });
}
