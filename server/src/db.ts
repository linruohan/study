import { Pool, type PoolClient } from 'pg';
import { config } from './config.js';

/// 全局连接池：素材接口都从这里取连接，避免每次请求重连。
export const pool = new Pool({
  connectionString: config.databaseUrl,
  max: 10,
  idleTimeoutMillis: 30_000,
  // 建连排队最多等 5 秒，坏查询最多占 30 秒，防止单类慢请求把池占满。
  connectionTimeoutMillis: 5_000,
  statement_timeout: 30_000,
});

export type { PoolClient };

/// 空闲连接被数据库单方面断开（例如服务重启）时不要让整个进程崩掉，
/// 连接池会在下次请求时自动重新建连。
pool.on('error', (error) => {
  console.error('数据库空闲连接异常，连接池将自动重连：', error.message);
});

/// 探活：能执行 select 1 就说明数据库连得上。
export async function pingDatabase(): Promise<void> {
  await pool.query('SELECT 1');
}

/// 进程退出前收掉连接池。
export async function closeDatabase(): Promise<void> {
  await pool.end();
}
