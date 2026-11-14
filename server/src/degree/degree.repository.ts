import { pool } from '../db.js';
import { HttpError } from '../http/errors.js';

/// 九境三阶：境界与所属阶。识构通 / 辨创立 / 化宗道。
export const REALMS = ['shi', 'gou', 'tong', 'bian', 'chuang', 'li', 'hua', 'zong', 'dao'] as const;

const REALM_STAGE: Record<string, 'early' | 'middle' | 'late'> = {
  shi: 'early',
  gou: 'early',
  tong: 'early',
  bian: 'middle',
  chuang: 'middle',
  li: 'middle',
  hua: 'late',
  zong: 'late',
  dao: 'late',
};

export const REALM_LABELS: Record<string, string> = {
  none: '未入门',
  shi: '识境',
  gou: '构境',
  tong: '通境',
  bian: '辨境',
  chuang: '创境',
  li: '立境',
  hua: '化境',
  zong: '宗境',
  dao: '道境',
};

export interface DegreeState {
  realm: string;
  realmLabel: string;
  stage: string;
}

export interface DegreeApplication {
  id: string;
  userId: string;
  targetRealm: string;
  targetRealmLabel: string;
  evidence: Record<string, unknown>;
  status: 'pending' | 'approved' | 'rejected';
  createdAt: string;
  reviewedAt: string | null;
}

interface ApplicationRow {
  id: string;
  user_id: string;
  target_realm: string;
  evidence: unknown;
  status: 'pending' | 'approved' | 'rejected';
  created_at: Date;
  reviewed_at: Date | null;
}

function toApplication(row: ApplicationRow): DegreeApplication {
  return {
    id: row.id,
    userId: row.user_id,
    targetRealm: row.target_realm,
    targetRealmLabel: REALM_LABELS[row.target_realm] ?? row.target_realm,
    evidence: (row.evidence ?? {}) as Record<string, unknown>,
    status: row.status,
    createdAt: row.created_at.toISOString(),
    reviewedAt: row.reviewed_at?.toISOString() ?? null,
  };
}

export async function myDegree(userId: string): Promise<DegreeState> {
  try {
    const result = await pool.query<{ realm: string; stage: string }>(
      'SELECT realm, stage FROM user_degrees WHERE user_id = $1',
      [userId],
    );
    const row = result.rows[0];
    if (!row) {
      return { realm: 'none', realmLabel: REALM_LABELS.none, stage: 'early' };
    }
    return { realm: row.realm, realmLabel: REALM_LABELS[row.realm] ?? row.realm, stage: row.stage };
  } catch (error) {
    if ((error as { code?: string }).code === '42P01') {
      throw new HttpError(503, 'migration_required', '学位功能尚未启用，请先执行数据库迁移');
    }
    throw error;
  }
}

export async function submitApplication(
  userId: string,
  targetRealm: string,
  evidence: Record<string, unknown>,
): Promise<DegreeApplication> {
  // 检查 + 插入放在同一事务里，并配合 025 迁移的部分唯一索引，
  // 防止并发提交绕过「同时只允许一条待审申请」的规则。
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const pending = await client.query(
      `SELECT 1 FROM degree_applications WHERE user_id = $1 AND status = 'pending' FOR UPDATE`,
      [userId],
    );
    if (pending.rowCount && pending.rowCount > 0) {
      throw new HttpError(409, 'application_pending', '已有一条待审核的学位申请');
    }
    const result = await client.query<ApplicationRow>(
      `INSERT INTO degree_applications (user_id, target_realm, evidence)
       VALUES ($1, $2, $3)
       RETURNING id, user_id, target_realm, evidence, status, created_at, reviewed_at`,
      [userId, targetRealm, JSON.stringify(evidence)],
    );
    await client.query('COMMIT');
    return toApplication(result.rows[0]);
  } catch (error) {
    await client.query('ROLLBACK').catch(() => undefined);
    if ((error as { code?: string }).code === '42P01') {
      throw new HttpError(503, 'migration_required', '学位功能尚未启用，请先执行数据库迁移');
    }
    if ((error as { code?: string }).code === '23505') {
      throw new HttpError(409, 'application_pending', '已有一条待审核的学位申请');
    }
    throw error;
  } finally {
    client.release();
  }
}

export async function myApplications(
  userId: string,
  limit = 50,
  offset = 0,
): Promise<DegreeApplication[]> {
  try {
    const result = await pool.query<ApplicationRow>(
      `SELECT id, user_id, target_realm, evidence, status, created_at, reviewed_at
         FROM degree_applications
        WHERE user_id = $1
        ORDER BY created_at DESC
        LIMIT $2 OFFSET $3`,
      [userId, Math.min(Math.max(limit, 1), 200), Math.max(offset, 0)],
    );
    return result.rows.map(toApplication);
  } catch (error) {
    if ((error as { code?: string }).code === '42P01') {
      throw new HttpError(503, 'migration_required', '学位功能尚未启用，请先执行数据库迁移');
    }
    throw error;
  }
}

export async function listApplications(
  status: 'pending' | 'approved' | 'rejected' | 'all',
  limit = 50,
  offset = 0,
): Promise<DegreeApplication[]> {
  try {
    const where = status === 'all' ? '' : 'WHERE status = $3';
    const result = await pool.query<ApplicationRow>(
      `SELECT id, user_id, target_realm, evidence, status, created_at, reviewed_at
         FROM degree_applications
        ${where}
        ORDER BY created_at DESC
        LIMIT $1 OFFSET $2`,
      status === 'all'
        ? [Math.min(Math.max(limit, 1), 200), Math.max(offset, 0)]
        : [Math.min(Math.max(limit, 1), 200), Math.max(offset, 0), status],
    );
    return result.rows.map(toApplication);
  } catch (error) {
    if ((error as { code?: string }).code === '42P01') {
      throw new HttpError(503, 'migration_required', '学位功能尚未启用，请先执行数据库迁移');
    }
    throw error;
  }
}

/// 审核学位申请：通过即把用户境界提升到目标境界（授予即定格进账本）。
export async function reviewApplication(
  applicationId: string,
  reviewerId: string,
  approve: boolean,
): Promise<DegreeApplication> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const current = await client.query<ApplicationRow>(
      `SELECT id, user_id, target_realm, evidence, status, created_at, reviewed_at
         FROM degree_applications
        WHERE id = $1
        FOR UPDATE`,
      [applicationId],
    );
    const row = current.rows[0];
    if (!row) {
      throw new HttpError(404, 'not_found', '学位申请不存在');
    }
    if (row.status !== 'pending') {
      throw new HttpError(409, 'already_reviewed', '该申请已审核');
    }
    const updated = await client.query<ApplicationRow>(
      `UPDATE degree_applications
          SET status = $2, reviewer_id = $3, reviewed_at = now()
        WHERE id = $1
      RETURNING id, user_id, target_realm, evidence, status, created_at, reviewed_at`,
      [applicationId, approve ? 'approved' : 'rejected', reviewerId],
    );
    if (approve) {
      const stage = REALM_STAGE[row.target_realm] ?? 'early';
      await client.query(
        `INSERT INTO user_degrees (user_id, realm, stage, updated_at)
         VALUES ($1, $2, $3, now())
         ON CONFLICT (user_id) DO UPDATE
            SET realm = EXCLUDED.realm, stage = EXCLUDED.stage, updated_at = now()`,
        [row.user_id, row.target_realm, stage],
      );
    }
    await client.query('COMMIT');
    return toApplication(updated.rows[0]);
  } catch (error) {
    await client.query('ROLLBACK');
    if ((error as { code?: string }).code === '42P01') {
      throw new HttpError(503, 'migration_required', '学位功能尚未启用，请先执行数据库迁移');
    }
    throw error;
  } finally {
    client.release();
  }
}
