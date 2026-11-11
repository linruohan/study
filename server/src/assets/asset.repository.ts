import { pool } from '../db.js';
import type { AssetKind, AssetRecord, NewAsset } from './asset.types.js';

/// 查询时显式列出字段，避免以后加列时把正文一起带进列表接口。
const COLUMNS = [
  'id',
  'kind',
  'title',
  'mime_type',
  'body',
  'bucket',
  'object_key',
  'size_bytes',
  'sha256',
  'width',
  'height',
  'duration_ms',
  'metadata',
  'created_at',
  'updated_at',
].join(', ');

/// 数据库行：bigint 会被 pg 当字符串返回，时间列是 Date。
interface AssetRow {
  id: string;
  kind: AssetKind;
  title: string;
  mime_type: string;
  body: string | null;
  bucket: string | null;
  object_key: string | null;
  size_bytes: string;
  sha256: string | null;
  width: number | null;
  height: number | null;
  duration_ms: number | null;
  metadata: Record<string, unknown>;
  created_at: Date;
  updated_at: Date;
}

/// 把蛇形行转换成接口里用的驼峰对象。
function toRecord(row: AssetRow): AssetRecord {
  return {
    id: row.id,
    kind: row.kind,
    title: row.title,
    mimeType: row.mime_type,
    body: row.body,
    bucket: row.bucket,
    objectKey: row.object_key,
    sizeBytes: Number(row.size_bytes),
    sha256: row.sha256,
    width: row.width,
    height: row.height,
    durationMs: row.duration_ms,
    metadata: row.metadata ?? {},
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

/// 插入一条素材，返回入库后的完整记录。
export async function insertAsset(input: NewAsset): Promise<AssetRecord> {
  const { rows } = await pool.query<AssetRow>(
    `INSERT INTO assets
       (id, kind, title, mime_type, body, bucket, object_key, size_bytes, sha256, metadata)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
     RETURNING ${COLUMNS}`,
    [
      input.id,
      input.kind,
      input.title,
      input.mimeType,
      input.body ?? null,
      input.bucket ?? null,
      input.objectKey ?? null,
      input.sizeBytes,
      input.sha256 ?? null,
      JSON.stringify(input.metadata ?? {}),
    ],
  );
  const row = rows[0];
  if (!row) {
    throw new Error('素材写入后没有返回记录');
  }
  return toRecord(row);
}

/// 按 id 查一条素材；没有就返回 null。
export async function findAsset(id: string): Promise<AssetRecord | null> {
  const { rows } = await pool.query<AssetRow>(
    `SELECT ${COLUMNS} FROM assets WHERE id = $1`,
    [id],
  );
  const row = rows[0];
  return row ? toRecord(row) : null;
}

/// 按种类分页列出素材，最新的排前面。
export async function listAssets(filter: {
  kind?: AssetKind;
  limit: number;
  offset: number;
}): Promise<AssetRecord[]> {
  const { rows } = await pool.query<AssetRow>(
    `SELECT ${COLUMNS}
       FROM assets
      WHERE ($1::text IS NULL OR kind = $1)
      ORDER BY created_at DESC
      LIMIT $2 OFFSET $3`,
    [filter.kind ?? null, filter.limit, filter.offset],
  );
  return rows.map(toRecord);
}

/// 删除一条素材记录；返回是否真的删掉了。
export async function removeAsset(id: string): Promise<boolean> {
  const result = await pool.query('DELETE FROM assets WHERE id = $1', [id]);
  return (result.rowCount ?? 0) > 0;
}
