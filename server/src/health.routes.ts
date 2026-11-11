import type { FastifyInstance } from 'fastify';
import { pingDatabase } from './db.js';
import { pingStorage } from './storage.js';

/// 探活小工具：成功返回 true，失败把原因交给调用方记录。
async function check(task: () => Promise<void>): Promise<boolean> {
  try {
    await task();
    return true;
  } catch {
    return false;
  }
}

/// 健康检查：数据库和对象存储都通才算健康。
export async function healthRoutes(app: FastifyInstance): Promise<void> {
  app.get('/healthz', async (_request, reply) => {
    const [database, storage] = await Promise.all([
      check(pingDatabase),
      check(pingStorage),
    ]);
    const ok = database && storage;
    return reply.code(ok ? 200 : 503).send({
      ok,
      database: database ? 'up' : 'down',
      storage: storage ? 'up' : 'down',
      uptimeSeconds: Math.round(process.uptime()),
    });
  });
}
