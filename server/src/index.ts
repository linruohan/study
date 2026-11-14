import { buildApp } from './app.js';
import { config } from './config.js';
import { closeDatabase } from './db.js';
import { ensureBucket } from './storage.js';

/// 启动流程：先建好桶，再监听端口；缺一样就直接失败，避免半可用。
async function main(): Promise<void> {
  const app = await buildApp();

  await ensureBucket();
  await app.listen({ port: config.port, host: '0.0.0.0' });
  app.log.info(`素材服务已启动：http://127.0.0.1:${config.port}`);

  const shutdown = async (signal: string): Promise<void> => {
    app.log.info(`收到 ${signal}，准备关闭`);
    await app.close();
    await closeDatabase();
    process.exit(0);
  };

  process.on('SIGINT', () => void shutdown('SIGINT'));
  process.on('SIGTERM', () => void shutdown('SIGTERM'));

  // 兜底：未处理的 promise 拒绝记日志不退出；未捕获异常记日志后走优雅关闭。
  process.on('unhandledRejection', (reason) => {
    app.log.error({ err: reason }, '未处理的 promise 拒绝');
  });
  process.on('uncaughtException', (error) => {
    app.log.error({ err: error }, '未捕获异常，准备退出');
    void shutdown('uncaughtException');
  });
}

main().catch((error: unknown) => {
  console.error('启动失败', error);
  process.exit(1);
});
