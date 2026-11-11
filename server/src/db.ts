import { Pool } from 'pg';
import { config } from './config.js';

/// 全局连接池：素材接口都从这里取连接，避免每次请求重连。
export const pool = new Pool({
  connectionString: config.databaseUrl,
  max: 10,
  idleTimeoutMillis: 30_000,
});

/// 探活：能执行 select 1 就说明数据库连得上。
export async function pingDatabase(): Promise<void> {
  await pool.query('SELECT 1');
}

/// 进程退出前收掉连接池。
export async function closeDatabase(): Promise<void> {
  await pool.end();
}
