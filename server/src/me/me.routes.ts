import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { HttpError } from '../http/errors.js';
import * as repository from './me.repository.js';
import type { UserDataDto } from './me.types.js';

/// 设备 id 放在路径里，必须是 UUID。
const deviceParamsSchema = z.object({
  deviceId: z.string().uuid('设备 id 不是合法的 UUID'),
});

const profileSchema = z
  .object({
    band: z.string().trim().min(1).nullable().optional(),
    // 旧客户端/旧缓存可能还发 focusDomainId；统一落到 focusCategoryId。
    focusDomainId: z.string().trim().min(1).nullable().optional(),
    focusCategoryId: z.string().trim().min(1).nullable().optional(),
  })
  .transform((value) => ({
    band: value.band ?? null,
    focusCategoryId: value.focusCategoryId ?? value.focusDomainId ?? null,
  }));

const planSchema = z
  .object({
    id: z.string().trim().min(1).max(100),
    // 计划归属分类：新客户端发 categoryId，旧数据仍允许 domainId。
    domainId: z.string().trim().min(1).nullable().optional(),
    categoryId: z.string().trim().min(1).nullable().optional(),
    depth: z.enum(['brief', 'deep']),
    conceptId: z.string().trim().min(1).nullable().optional(),
    degree: z.string().trim().min(1).nullable().optional(),
    startAt: z.coerce.date(),
    remind: z.boolean().default(true),
    done: z.boolean().default(false),
    remindedAt: z.coerce.date().nullable().optional(),
    snoozedUntil: z.coerce.date().nullable().optional(),
  })
  .refine((value) => (value.categoryId ?? value.domainId) != null, {
    message: 'categoryId 不能为空',
    path: ['categoryId'],
  })
  .transform((value) => ({
    id: value.id,
    categoryId: (value.categoryId ?? value.domainId) as string,
    depth: value.depth,
    conceptId: value.conceptId ?? null,
    degree: value.degree ?? null,
    startAt: value.startAt.toISOString(),
    remind: value.remind,
    done: value.done,
    remindedAt: value.remindedAt?.toISOString() ?? null,
    snoozedUntil: value.snoozedUntil?.toISOString() ?? null,
  }));

const recordSchema = z
  .object({
    id: z.string().trim().min(1).max(100),
    at: z.coerce.date(),
    source: z.string().trim().min(1).max(50),
    subject: z.string().trim().min(1).max(200),
    body: z.string().trim().min(1).max(5_000),
    conceptId: z.string().trim().min(1).nullable().optional(),
    // 旧客户端/旧缓存可能还发 domainId；统一落到 categoryId。
    domainId: z.string().trim().min(1).nullable().optional(),
    categoryId: z.string().trim().min(1).nullable().optional(),
    ageBandId: z.string().trim().min(1).nullable().optional(),
  })
  .transform((value) => ({
    id: value.id,
    at: value.at.toISOString(),
    source: value.source,
    subject: value.subject,
    body: value.body,
    conceptId: value.conceptId ?? null,
    categoryId: value.categoryId ?? value.domainId ?? null,
    ageBandId: value.ageBandId ?? null,
  }));

const userDataSchema = z.object({
  profile: profileSchema.default({ band: null, focusCategoryId: null }),
  plans: z.array(planSchema).max(500).default([]),
  records: z.array(recordSchema).max(5_000).default([]),
});

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

/// 设备数据接口：一次读取设置、计划和记录，保存时整份替换。
export async function meRoutes(app: FastifyInstance): Promise<void> {
  app.get('/api/devices/:deviceId/data', async (request) => {
    const { deviceId } = parseOrThrow(deviceParamsSchema, request.params);
    return repository.loadUserData(deviceId);
  });

  app.put('/api/devices/:deviceId/data', async (request) => {
    const { deviceId } = parseOrThrow(deviceParamsSchema, request.params);
    const data = parseOrThrow(userDataSchema, request.body) as UserDataDto;
    return repository.saveUserData(deviceId, data);
  });
}
