import { readdir, readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { Pool } from 'pg';
import { config } from '../config.js';

/// db 目录固定在 server/db：src/scripts 和 dist/scripts 往上两级都能找到。
const scriptDir = dirname(fileURLToPath(import.meta.url));
const migrationsDir = join(scriptDir, '..', '..', 'db');

/// 执行 db 下的 SQL 文件；执行过的文件名记在 schema_migrations 里。
async function main(): Promise<void> {
  const pool = new Pool({ connectionString: config.databaseUrl });
  const client = await pool.connect();
  try {
    await client.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        filename text PRIMARY KEY,
        applied_at timestamptz NOT NULL DEFAULT now()
      )
    `);

    const files = (await readdir(migrationsDir))
      .filter((file) => file.endsWith('.sql'))
      .sort();

    if (files.length === 0) {
      console.log('db 目录里没有 SQL 文件');
      return;
    }

    for (const file of files) {
      const applied = await client.query(
        'SELECT 1 FROM schema_migrations WHERE filename = $1',
        [file],
      );
      if (applied.rowCount) {
        console.log(`跳过 ${file}（已经执行过）`);
        continue;
      }

      const sql = await readFile(join(migrationsDir, file), 'utf8');
      console.log(`执行 ${file}`);
      await client.query('BEGIN');
      try {
        await client.query(sql);
        await client.query(
          'INSERT INTO schema_migrations (filename) VALUES ($1)',
          [file],
        );
        await client.query('COMMIT');
      } catch (error) {
        await client.query('ROLLBACK');
        throw error;
      }
    }

    console.log('数据库迁移完成');
  } finally {
    client.release();
    await pool.end();
  }
}

main().catch((error: unknown) => {
  console.error('迁移失败', error);
  process.exit(1);
});
