import 'dotenv/config';
import { z } from 'zod';

/// 环境变量校验：缺必需项时直接报错，避免服务带病启动。
const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  LOG_LEVEL: z
    .enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent'])
    .default('info'),
  PORT: z.coerce.number().int().min(1).max(65535).default(3000),
  DATABASE_URL: z.string().min(1, 'DATABASE_URL 不能为空'),
  S3_ENDPOINT: z.string().url('S3_ENDPOINT 需要是完整地址'),
  S3_REGION: z.string().default('us-east-1'),
  S3_ACCESS_KEY: z.string().min(1, 'S3_ACCESS_KEY 不能为空'),
  S3_SECRET_KEY: z.string().min(1, 'S3_SECRET_KEY 不能为空'),
  S3_BUCKET: z.string().min(3).default('study-assets'),
  // 上传走内存缓冲；超过 512MB 不该用整包缓冲（要改造成流式上传），把配置面收紧。
  MAX_UPLOAD_MB: z.coerce.number().positive().max(512).default(50),
  SIGNED_URL_TTL_SECONDS: z.coerce.number().int().positive().max(86400).default(900),
  CORS_ORIGIN: z.string().default('*'),
});

const parsed = envSchema.safeParse(process.env);
if (!parsed.success) {
  const detail = parsed.error.issues
    .map((issue) => `${issue.path.join('.') || 'env'}: ${issue.message}`)
    .join('；');
  throw new Error(`环境变量配置有误：${detail}`);
}

const env = parsed.data;

/// 全项目只从这里读配置，避免各处散落 process.env。
export const config = {
  nodeEnv: env.NODE_ENV,
  logLevel: env.LOG_LEVEL,
  port: env.PORT,
  databaseUrl: env.DATABASE_URL,
  s3: {
    endpoint: env.S3_ENDPOINT,
    region: env.S3_REGION,
    accessKey: env.S3_ACCESS_KEY,
    secretKey: env.S3_SECRET_KEY,
    bucket: env.S3_BUCKET,
  },
  maxUploadBytes: Math.floor(env.MAX_UPLOAD_MB * 1024 * 1024),
  signedUrlTtlSeconds: env.SIGNED_URL_TTL_SECONDS,
  corsOrigin: env.CORS_ORIGIN,
} as const;
