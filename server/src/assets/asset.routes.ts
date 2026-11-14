import { extname } from 'node:path';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { requireAuth } from '../auth/auth.hooks.js';
import { HttpError } from '../http/errors.js';
import * as service from './asset.service.js';

/// 素材种类，与数据库里的约束保持一致。
const assetKindSchema = z.enum(['image', 'audio', 'video', 'text']);

const idParamsSchema = z.object({
  id: z.string().uuid('素材 id 不是合法的 UUID'),
});

const listQuerySchema = z.object({
  kind: assetKindSchema.optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

const textAssetSchema = z.object({
  title: z.string().trim().min(1, '标题不能为空').max(200),
  body: z.string().min(1, '正文不能为空').max(500_000),
  mimeType: z.string().trim().min(1).default('text/plain'),
  metadata: z.record(z.unknown()).default({}),
});

/// 校验并返回数据；不通过就转成 400，路由里不用重复写 if。
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

/// 从 multipart 的普通字段里取一个字符串值。
function readField(fields: Record<string, unknown>, name: string): string | undefined {
  const raw = fields[name];
  const field = Array.isArray(raw) ? raw[0] : raw;
  if (field && typeof field === 'object' && 'value' in field) {
    const value = (field as { value: unknown }).value;
    return typeof value === 'string' ? value : undefined;
  }
  return undefined;
}

/// metadata 用 JSON 字符串传，解析失败直接报 400。
function parseMetadata(raw: string | undefined): Record<string, unknown> {
  if (!raw) {
    return {};
  }
  try {
    const value: unknown = JSON.parse(raw);
    if (!value || typeof value !== 'object' || Array.isArray(value)) {
      throw new Error('metadata 不是对象');
    }
    return value as Record<string, unknown>;
  } catch {
    throw new HttpError(400, 'invalid_metadata', 'metadata 需要是 JSON 对象');
  }
}

/// 素材相关接口：上传、列表、详情、取内容、删除。
/// 读操作（列表/详情/内容）保持匿名开放；写操作（上传/删除）需要登录。
export async function assetRoutes(app: FastifyInstance): Promise<void> {
  // 纯文本：正文直接入库。
  app.post('/api/assets/text', { preHandler: requireAuth }, async (request, reply) => {
    const input = parseOrThrow(textAssetSchema, request.body);
    const asset = await service.createTextAsset(input);
    return reply
      .code(201)
      .send(service.toAssetResponse(asset, { includeBody: true }));
  });

  // 图片、音频、视频：multipart 上传，字段名 file。
  app.post('/api/assets', { preHandler: requireAuth }, async (request, reply) => {
    const file = await request.file();
    if (!file) {
      throw new HttpError(
        400,
        'file_required',
        '请用 multipart/form-data 上传，字段名 file',
      );
    }
    const buffer = await file.toBuffer();
    const asset = await service.createMediaAsset({
      buffer,
      mimeType: file.mimetype,
      filename: file.filename,
      title: readField(file.fields, 'title'),
      metadata: parseMetadata(readField(file.fields, 'metadata')),
    });
    return reply.code(201).send(service.toAssetResponse(asset));
  });

  // 列表：默认最新的 20 条，可按种类过滤。
  app.get('/api/assets', async (request) => {
    const query = parseOrThrow(listQuerySchema, request.query);
    const items = await service.listAssets(query);
    return {
      items: items.map((asset) => service.toAssetResponse(asset)),
      limit: query.limit,
      offset: query.offset,
    };
  });

  // 详情：文本资源会把正文一并带回。
  app.get('/api/assets/:id', async (request) => {
    const { id } = parseOrThrow(idParamsSchema, request.params);
    const asset = await service.getAssetOrThrow(id);
    return service.toAssetResponse(asset, { includeBody: true });
  });

  // 取内容：文本直接回正文，媒体 302 到短期预签名地址。
  app.get('/api/assets/:id/content', async (request, reply) => {
    const { id } = parseOrThrow(idParamsSchema, request.params);
    const asset = await service.getAssetOrThrow(id);
    const wantsDownload =
      (request.query as { download?: string }).download === '1';
    const downloadName = wantsDownload
      ? `${asset.title}${asset.objectKey ? extname(asset.objectKey) : ''}`
      : undefined;

    if (asset.kind === 'text') {
      if (downloadName) {
        reply.header(
          'content-disposition',
          `attachment; filename*=UTF-8''${encodeURIComponent(downloadName)}`,
        );
      }
      return reply
        .type(`${asset.mimeType}; charset=utf-8`)
        .send(asset.body ?? '');
    }

    const url = await service.mediaUrlFor(asset, downloadName);
    return reply
      .header('cache-control', 'no-store')
      .code(302)
      .header('location', url)
      .send();
  });

  // 删除：对象和记录一起清掉。
  app.delete('/api/assets/:id', { preHandler: requireAuth }, async (request, reply) => {
    const { id } = parseOrThrow(idParamsSchema, request.params);
    await service.deleteAsset(id);
    return reply.code(204).send();
  });
}
