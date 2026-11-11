import { createHash, randomUUID } from 'node:crypto';
import { basename, extname } from 'node:path';
import { config } from '../config.js';
import { HttpError } from '../http/errors.js';
import { deleteObject, putObject, signedGetUrl } from '../storage.js';
import * as repository from './asset.repository.js';
import type { AssetKind, AssetRecord } from './asset.types.js';

/// 媒体种类：文本之外的三种，本体都在对象存储里。
type MediaKind = Exclude<AssetKind, 'text'>;

/// 常见 MIME 对应的扩展名，文件没带后缀时兜底。
const EXTENSION_BY_MIME: Record<string, string> = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
  'image/gif': '.gif',
  'audio/mpeg': '.mp3',
  'audio/mp4': '.m4a',
  'audio/wav': '.wav',
  'audio/ogg': '.ogg',
  'video/mp4': '.mp4',
  'video/webm': '.webm',
  'video/quicktime': '.mov',
};

/// 按 MIME 前缀判断是图片、音频还是视频。
export function mediaKindFromMime(mimeType: string): MediaKind | null {
  const mime = mimeType.toLowerCase();
  if (mime.startsWith('image/')) {
    return 'image';
  }
  if (mime.startsWith('audio/')) {
    return 'audio';
  }
  if (mime.startsWith('video/')) {
    return 'video';
  }
  return null;
}

/// 取一个安全的扩展名：优先用原文件名，其次按 MIME 猜。
function safeExtension(filename: string, mimeType: string): string {
  const fromName = extname(filename).toLowerCase();
  if (/^\.[a-z0-9]{1,8}$/.test(fromName)) {
    return fromName;
  }
  return EXTENSION_BY_MIME[mimeType.toLowerCase()] ?? '';
}

/// 对象键按「种类/年/月/id.后缀」分层，方便以后按前缀归档或清理。
function buildObjectKey(
  kind: MediaKind,
  id: string,
  extension: string,
): string {
  const now = new Date();
  const year = now.getUTCFullYear();
  const month = String(now.getUTCMonth() + 1).padStart(2, '0');
  return `${kind}/${year}/${month}/${id}${extension}`;
}

/// 没有标题时用文件名兜底，去掉后缀并截断到 200 字。
function titleFromFilename(filename: string): string {
  const name = basename(filename, extname(filename)).trim();
  return (name || '未命名素材').slice(0, 200);
}

/// 新建一条纯文本素材：正文直接入库，不碰对象存储。
export async function createTextAsset(input: {
  title: string;
  body: string;
  mimeType: string;
  metadata: Record<string, unknown>;
}): Promise<AssetRecord> {
  const sizeBytes = Buffer.byteLength(input.body, 'utf8');
  const sha256 = createHash('sha256').update(input.body, 'utf8').digest('hex');
  return repository.insertAsset({
    id: randomUUID(),
    kind: 'text',
    title: input.title,
    mimeType: input.mimeType,
    body: input.body,
    sizeBytes,
    sha256,
    metadata: input.metadata,
  });
}

/// 新建一条媒体素材：文件先进 MinIO，再写元数据；写库失败就把对象删掉。
export async function createMediaAsset(input: {
  buffer: Buffer;
  mimeType: string;
  filename: string;
  title?: string;
  metadata: Record<string, unknown>;
}): Promise<AssetRecord> {
  const kind = mediaKindFromMime(input.mimeType);
  if (!kind) {
    throw new HttpError(
      415,
      'unsupported_media_type',
      '只支持图片、音频、视频；纯文本请走 POST /api/assets/text',
    );
  }
  if (input.buffer.byteLength === 0) {
    throw new HttpError(400, 'empty_file', '文件是空的，换一个再传');
  }
  if (input.buffer.byteLength > config.maxUploadBytes) {
    throw new HttpError(
      413,
      'file_too_large',
      `文件超过 ${Math.round(config.maxUploadBytes / 1024 / 1024)} MB 限制`,
    );
  }

  const id = randomUUID();
  const objectKey = buildObjectKey(
    kind,
    id,
    safeExtension(input.filename, input.mimeType),
  );
  const sha256 = createHash('sha256').update(input.buffer).digest('hex');

  await putObject(objectKey, input.buffer, input.mimeType);
  try {
    return await repository.insertAsset({
      id,
      kind,
      title: input.title?.trim() || titleFromFilename(input.filename),
      mimeType: input.mimeType,
      bucket: config.s3.bucket,
      objectKey,
      sizeBytes: input.buffer.byteLength,
      sha256,
      metadata: input.metadata,
    });
  } catch (error) {
    // 记录没写进去，对象也不该留下，否则以后没人能对上。
    await deleteObject(objectKey).catch(() => undefined);
    throw error;
  }
}

/// 查一条素材，查不到就抛 404。
export async function getAssetOrThrow(id: string): Promise<AssetRecord> {
  const asset = await repository.findAsset(id);
  if (!asset) {
    throw new HttpError(404, 'asset_not_found', '没有找到这条素材');
  }
  return asset;
}

/// 分页列出素材。
export async function listAssets(filter: {
  kind?: AssetKind;
  limit: number;
  offset: number;
}): Promise<AssetRecord[]> {
  return repository.listAssets(filter);
}

/// 删除素材：先删对象，再删记录。
export async function deleteAsset(id: string): Promise<void> {
  const asset = await getAssetOrThrow(id);
  if (asset.objectKey) {
    await deleteObject(asset.objectKey);
  }
  await repository.removeAsset(id);
}

/// 生成媒体素材的短期访问地址。
export async function mediaUrlFor(
  asset: AssetRecord,
  downloadName?: string,
): Promise<string> {
  if (!asset.objectKey) {
    throw new HttpError(400, 'not_a_media_asset', '这条素材没有对象文件');
  }
  return signedGetUrl(asset.objectKey, {
    mimeType: asset.mimeType,
    downloadName,
  });
}

/// 接口返回结构：列表不带正文，详情才带。
export interface AssetResponse {
  id: string;
  kind: AssetKind;
  title: string;
  mimeType: string;
  sizeBytes: number;
  sha256: string | null;
  width: number | null;
  height: number | null;
  durationMs: number | null;
  metadata: Record<string, unknown>;
  contentUrl: string;
  createdAt: string;
  updatedAt: string;
  body?: string | null;
}

/// 把内部记录转成对外的 JSON，时间统一 ISO 字符串。
export function toAssetResponse(
  asset: AssetRecord,
  options: { includeBody?: boolean } = {},
): AssetResponse {
  return {
    id: asset.id,
    kind: asset.kind,
    title: asset.title,
    mimeType: asset.mimeType,
    sizeBytes: asset.sizeBytes,
    sha256: asset.sha256,
    width: asset.width,
    height: asset.height,
    durationMs: asset.durationMs,
    metadata: asset.metadata,
    contentUrl: `/api/assets/${asset.id}/content`,
    createdAt: asset.createdAt.toISOString(),
    updatedAt: asset.updatedAt.toISOString(),
    ...(options.includeBody ? { body: asset.body } : {}),
  };
}
