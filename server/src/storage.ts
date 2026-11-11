import {
  CreateBucketCommand,
  DeleteObjectCommand,
  GetObjectCommand,
  HeadBucketCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { config } from './config.js';

/// S3 客户端：MinIO 需要 path-style，所以 forcePathStyle 固定打开。
///
/// requestChecksumCalculation / responseChecksumValidation 设成 WHEN_REQUIRED，
/// 是为了兼容不实现 flexible checksum 的 S3 服务（如 SeaweedFS），
/// 否则 SDK 会额外带 x-amz-checksum-mode，导致预签名地址验签失败。
export const s3 = new S3Client({
  endpoint: config.s3.endpoint,
  region: config.s3.region,
  credentials: {
    accessKeyId: config.s3.accessKey,
    secretAccessKey: config.s3.secretKey,
  },
  forcePathStyle: true,
  requestChecksumCalculation: 'WHEN_REQUIRED',
  responseChecksumValidation: 'WHEN_REQUIRED',
});

/// 确认桶存在；首次启动或换了环境时自动建一个。
///
/// 刚 `docker compose up` 时 MinIO 可能还没就绪，所以这里重试若干次。
export async function ensureBucket(): Promise<void> {
  const bucket = config.s3.bucket;
  let lastError: unknown;
  for (let attempt = 1; attempt <= 10; attempt += 1) {
    try {
      await s3.send(new HeadBucketCommand({ Bucket: bucket }));
      return;
    } catch {
      try {
        await s3.send(new CreateBucketCommand({ Bucket: bucket }));
        return;
      } catch (error) {
        const name =
          error && typeof error === 'object' && 'name' in error
            ? String((error as { name?: unknown }).name)
            : '';
        // 并发启动时可能已经由别的进程建好了，也算成功。
        if (name === 'BucketAlreadyOwnedByYou' || name === 'BucketAlreadyExists') {
          return;
        }
        lastError = error;
        await new Promise((resolve) => setTimeout(resolve, 1000));
      }
    }
  }
  throw lastError instanceof Error
    ? lastError
    : new Error('对象存储初始化失败');
}

/// 上传文件本体，contentType 会跟着对象存下来，取回时不用再猜。
export async function putObject(
  key: string,
  body: Buffer,
  contentType: string,
): Promise<void> {
  await s3.send(
    new PutObjectCommand({
      Bucket: config.s3.bucket,
      Key: key,
      Body: body,
      ContentType: contentType,
    }),
  );
}

/// 删除对象；记录删除失败时用来补偿，避免库里留下孤儿数据。
export async function deleteObject(key: string): Promise<void> {
  await s3.send(
    new DeleteObjectCommand({ Bucket: config.s3.bucket, Key: key }),
  );
}

/// 存储探活：桶读得到就算正常。
export async function pingStorage(): Promise<void> {
  await s3.send(new HeadBucketCommand({ Bucket: config.s3.bucket }));
}

/// 生成短期访问地址；downloadName 有值时按附件下载。
export async function signedGetUrl(
  key: string,
  options: { mimeType?: string; downloadName?: string; expiresIn?: number } = {},
): Promise<string> {
  const command = new GetObjectCommand({
    Bucket: config.s3.bucket,
    Key: key,
    ResponseContentType: options.mimeType,
    ResponseContentDisposition: options.downloadName
      ? `attachment; filename*=UTF-8''${encodeURIComponent(options.downloadName)}`
      : undefined,
  });
  return getSignedUrl(s3, command, {
    expiresIn: options.expiresIn ?? config.signedUrlTtlSeconds,
  });
}
