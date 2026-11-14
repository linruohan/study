import cors from '@fastify/cors';
import multipart from '@fastify/multipart';
import Fastify, { type FastifyInstance } from 'fastify';
import { assetRoutes } from './assets/asset.routes.js';
import { authRoutes } from './auth/auth.routes.js';
import { ensureAdminUser } from './auth/auth.repository.js';
import { config } from './config.js';
import { degreeRoutes } from './degree/degree.routes.js';
import { healthRoutes } from './health.routes.js';
import { HttpError } from './http/errors.js';
import { ensureBucket } from './storage.js';
import { chapterRoutes } from './knowledge/chapter.routes.js';
import { knowledgeRoutes } from './knowledge/knowledge.routes.js';
import { pointFeedbackRoutes } from './knowledge/point_feedback.routes.js';
import { sageRoutes } from './knowledge/sage.routes.js';
import { meRoutes } from './me/me.routes.js';
import { planSchemeRoutes } from './plan_scheme/plan_scheme.routes.js';

/// 组装 Fastify 应用：插件、路由和统一的错误出口都在这里。
export async function buildApp(): Promise<FastifyInstance> {
  const app = Fastify({
    logger: { level: config.logLevel },
    // multipart 的解析有独立上限，这里再留一点余量给普通 JSON。
    bodyLimit: config.maxUploadBytes + 1024 * 1024,
  });

  // 错误处理和 404 要先挂，后注册的路由才能继承到。
  app.setNotFoundHandler((request, reply) => {
    return reply.code(404).send({
      error: {
        code: 'not_found',
        message: `没有这个接口：${request.method} ${request.url}`,
      },
    });
  });

  app.setErrorHandler((error, request, reply) => {
    // Fastify 的 error 参数在类型上是 unknown，这里按需要的字段收窄。
    const detail = error as {
      code?: string;
      statusCode?: number;
      message?: string;
      isHttpError?: boolean;
    };
    if (error instanceof HttpError || detail.isHttpError === true) {
      return reply.code(detail.statusCode ?? 500).send({
        error: {
          code: detail.code ?? 'request_error',
          message: detail.message ?? '请求有误',
        },
      });
    }
    if (detail.code === 'FST_REQ_FILE_TOO_LARGE' || detail.statusCode === 413) {
      const limitMb = Math.round(config.maxUploadBytes / 1024 / 1024);
      return reply.code(413).send({
        error: {
          code: 'file_too_large',
          message: `文件超过 ${limitMb} MB 限制`,
        },
      });
    }
    request.log.error({ err: error }, '未处理的请求错误');
    const status =
      detail.statusCode && detail.statusCode >= 400 ? detail.statusCode : 500;
    return reply
      .code(status)
      .send({ error: { code: 'internal_error', message: '服务出了点问题，稍后再试' } });
  });

  await app.register(cors, {
    origin:
      config.corsOrigin === '*'
        ? true
        : config.corsOrigin.split(',').map((item) => item.trim()),
  });
  await app.register(multipart, {
    limits: {
      fileSize: config.maxUploadBytes,
      files: 1,
      fields: 10,
    },
  });

  await app.register(healthRoutes);
  await app.register(assetRoutes);
  await app.register(authRoutes);
  await app.register(degreeRoutes);
  await app.register(knowledgeRoutes);
  await app.register(sageRoutes);
  await app.register(pointFeedbackRoutes);
  await app.register(chapterRoutes);
  await app.register(meRoutes);
  await app.register(planSchemeRoutes);

  // 内置管理员（admin/admin，首登强制改密）；库还没迁移时会报错，由启动日志暴露。
  await ensureAdminUser();

  // 桶不存在就建一个（幂等、带就绪重试）。放在 buildApp 里而不是启动脚本，
  // 这样测试或任何 buildApp 引导在全新卷上也能自愈，健康检查不会 503。
  await ensureBucket();

  return app;
}
