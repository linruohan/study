import { pool } from '../db.js';
import { HttpError } from '../http/errors.js';
import type { CommentDto, CorrectionDto, CreditDto, PointRef } from './point_feedback.types.js';

interface CommentRow {
  id: string;
  concept_id: string;
  age_band_id: string;
  degree_id: string;
  point_position: number;
  device_id: string;
  body: string;
  created_at: Date;
}

interface CorrectionRow {
  id: string;
  concept_id: string;
  age_band_id: string;
  degree_id: string;
  point_position: number;
  device_id: string;
  body: string;
  suggested_text: string | null;
  status: 'pending' | 'approved' | 'rejected';
  reviewed_at: Date | null;
  reviewer_device_id: string | null;
  points_awarded: number;
  created_at: Date;
}

function toPgError(error: unknown): unknown {
  const code = (error as { code?: string }).code;
  if (code === '23503') {
    return new HttpError(400, 'unknown_reference', '知识点、设备或关联数据不存在');
  }
  if (code === '42P01') {
    return new HttpError(503, 'migration_required', '知识点互动功能尚未启用，请先执行数据库迁移');
  }
  return error;
}

async function touchDevice(
  client: { query: (sql: string, params?: unknown[]) => Promise<unknown> },
  deviceId: string,
): Promise<void> {
  await client.query(
    `INSERT INTO devices (id, last_seen_at)
     VALUES ($1, now())
     ON CONFLICT (id) DO UPDATE SET last_seen_at = now()`,
    [deviceId],
  );
}

async function assertPointExists(ref: PointRef): Promise<void> {
  const result = await pool.query(
    `SELECT 1 FROM knowledge_variant_points
      WHERE concept_id = $1 AND age_band_id = $2 AND degree_id = $3 AND position = $4`,
    [ref.conceptId, ref.ageBandId, ref.degreeId, ref.position],
  );
  if (result.rowCount === 0) {
    throw new HttpError(404, 'not_found', '知识点不存在');
  }
}

export async function listComments(ref: PointRef, limit = 50, offset = 0): Promise<CommentDto[]> {
  await assertPointExists(ref);
  const safeLimit = Math.min(Math.max(limit, 1), 200);
  const safeOffset = Math.max(offset, 0);
  try {
    const result = await pool.query<CommentRow>(
      `SELECT id, concept_id, age_band_id, degree_id, point_position, device_id, body, created_at
         FROM knowledge_point_comments
        WHERE concept_id = $1 AND age_band_id = $2 AND degree_id = $3 AND point_position = $4
        ORDER BY created_at DESC
        LIMIT $5 OFFSET $6`,
      [ref.conceptId, ref.ageBandId, ref.degreeId, ref.position, safeLimit, safeOffset],
    );
    return result.rows.map(toCommentDto);
  } catch (error) {
    throw toPgError(error);
  }
}

export async function createComment(ref: PointRef, deviceId: string, body: string): Promise<CommentDto> {
  await assertPointExists(ref);
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await touchDevice(client, deviceId);
    const result = await client.query<CommentRow>(
      `INSERT INTO knowledge_point_comments
         (concept_id, age_band_id, degree_id, point_position, device_id, body)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING id, concept_id, age_band_id, degree_id, point_position, device_id, body, created_at`,
      [ref.conceptId, ref.ageBandId, ref.degreeId, ref.position, deviceId, body],
    );
    await client.query('COMMIT');
    return toCommentDto(result.rows[0]);
  } catch (error) {
    await client.query('ROLLBACK');
    throw toPgError(error);
  } finally {
    client.release();
  }
}

export async function listCorrections(ref: PointRef, limit = 50, offset = 0): Promise<CorrectionDto[]> {
  await assertPointExists(ref);
  const safeLimit = Math.min(Math.max(limit, 1), 200);
  const safeOffset = Math.max(offset, 0);
  try {
    const result = await pool.query<CorrectionRow>(
      `SELECT id, concept_id, age_band_id, degree_id, point_position, device_id, body, suggested_text,
              status, reviewed_at, reviewer_device_id, points_awarded, created_at
         FROM knowledge_point_corrections
        WHERE concept_id = $1 AND age_band_id = $2 AND degree_id = $3 AND point_position = $4
        ORDER BY created_at DESC
        LIMIT $5 OFFSET $6`,
      [ref.conceptId, ref.ageBandId, ref.degreeId, ref.position, safeLimit, safeOffset],
    );
    return result.rows.map(toCorrectionDto);
  } catch (error) {
    throw toPgError(error);
  }
}

export async function createCorrection(
  ref: PointRef,
  deviceId: string,
  body: string,
  suggestedText: string | null,
): Promise<CorrectionDto> {
  await assertPointExists(ref);
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await touchDevice(client, deviceId);
    const result = await client.query<CorrectionRow>(
      `INSERT INTO knowledge_point_corrections
         (concept_id, age_band_id, degree_id, point_position, device_id, body, suggested_text)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING id, concept_id, age_band_id, degree_id, point_position, device_id, body, suggested_text,
                 status, reviewed_at, reviewer_device_id, points_awarded, created_at`,
      [ref.conceptId, ref.ageBandId, ref.degreeId, ref.position, deviceId, body, suggestedText],
    );
    await client.query('COMMIT');
    return toCorrectionDto(result.rows[0]);
  } catch (error) {
    await client.query('ROLLBACK');
    throw toPgError(error);
  } finally {
    client.release();
  }
}

export async function reviewCorrection(
  correctionId: string,
  reviewerDeviceId: string,
  approve: boolean,
  points: number,
): Promise<CorrectionDto> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await touchDevice(client, reviewerDeviceId);
    const current = await client.query<CorrectionRow>(
      `SELECT id, concept_id, age_band_id, degree_id, point_position, device_id, body, suggested_text,
              status, reviewed_at, reviewer_device_id, points_awarded, created_at
         FROM knowledge_point_corrections
        WHERE id = $1
        FOR UPDATE`,
      [correctionId],
    );
    const row = current.rows[0];
    if (!row) {
      throw new HttpError(404, 'not_found', '纠错记录不存在');
    }
    if (row.status !== 'pending') {
      throw new HttpError(409, 'already_reviewed', '该纠错已审核');
    }
    const status = approve ? 'approved' : 'rejected';
    const pointsAwarded = approve ? points : 0;
    const updated = await client.query<CorrectionRow>(
      `UPDATE knowledge_point_corrections
          SET status = $2,
              reviewed_at = now(),
              reviewer_device_id = $3,
              points_awarded = $4
        WHERE id = $1
      RETURNING id, concept_id, age_band_id, degree_id, point_position, device_id, body, suggested_text,
                status, reviewed_at, reviewer_device_id, points_awarded, created_at`,
      [correctionId, status, reviewerDeviceId, pointsAwarded],
    );
    if (approve && pointsAwarded > 0) {
      await client.query(
        `INSERT INTO knowledge_point_credits (device_id, correction_id, amount, reason)
         VALUES ($1, $2, $3, $4)`,
        [row.device_id, correctionId, pointsAwarded, '知识点纠错审核通过奖励'],
      );
    }
    // 纠错闭环：通过且带修正文本时，把修正写回知识点正文。
    if (approve && row.suggested_text !== null && row.suggested_text.trim().length > 0) {
      await client.query(
        `UPDATE knowledge_variant_points
            SET point = $1
          WHERE concept_id = $2 AND age_band_id = $3 AND degree_id = $4 AND position = $5`,
        [row.suggested_text.trim(), row.concept_id, row.age_band_id, row.degree_id, row.point_position],
      );
    }
    await client.query('COMMIT');
    return toCorrectionDto(updated.rows[0]);
  } catch (error) {
    await client.query('ROLLBACK');
    throw toPgError(error);
  } finally {
    client.release();
  }
}

function toCommentDto(row: CommentRow): CommentDto {
  return {
    id: row.id,
    conceptId: row.concept_id,
    ageBandId: row.age_band_id,
    degreeId: row.degree_id,
    position: row.point_position,
    deviceId: row.device_id,
    body: row.body,
    createdAt: row.created_at.toISOString(),
  };
}

function toCorrectionDto(row: CorrectionRow): CorrectionDto {
  return {
    id: row.id,
    conceptId: row.concept_id,
    ageBandId: row.age_band_id,
    degreeId: row.degree_id,
    position: row.point_position,
    deviceId: row.device_id,
    body: row.body,
    suggestedText: row.suggested_text,
    status: row.status,
    reviewedAt: row.reviewed_at?.toISOString() ?? null,
    reviewerDeviceId: row.reviewer_device_id,
    pointsAwarded: row.points_awarded,
    createdAt: row.created_at.toISOString(),
  };
}

interface CreditRow {
  id: string;
  device_id: string;
  correction_id: string | null;
  amount: number;
  reason: string;
  created_at: Date;
}

export async function listCredits(deviceId: string, limit = 50, offset = 0): Promise<{ balance: number; items: CreditDto[] }> {
  const safeLimit = Math.min(Math.max(limit, 1), 200);
  const safeOffset = Math.max(offset, 0);
  try {
    const sumResult = await pool.query<{ balance: string | number }>(
      `SELECT COALESCE(SUM(amount), 0) AS balance FROM knowledge_point_credits WHERE device_id = $1`,
      [deviceId],
    );
    const result = await pool.query<CreditRow>(
      `SELECT id, device_id, correction_id, amount, reason, created_at
         FROM knowledge_point_credits
        WHERE device_id = $1
        ORDER BY created_at DESC
        LIMIT $2 OFFSET $3`,
      [deviceId, safeLimit, safeOffset],
    );
    const items = result.rows.map((row) => ({
      id: row.id,
      deviceId: row.device_id,
      correctionId: row.correction_id,
      amount: row.amount,
      reason: row.reason,
      createdAt: row.created_at.toISOString(),
    }));
    const raw = sumResult.rows[0]?.balance ?? 0;
    const balance = typeof raw === 'string' ? parseInt(raw, 10) || 0 : Number(raw) || 0;
    return { balance, items };
  } catch (error) {
    throw toPgError(error);
  }
}


export async function listPendingCorrections(limit = 50, offset = 0): Promise<CorrectionDto[]> {
  const safeLimit = Math.min(Math.max(limit, 1), 200);
  const safeOffset = Math.max(offset, 0);
  try {
    const result = await pool.query<CorrectionRow>(
      `SELECT id, concept_id, age_band_id, degree_id, point_position, device_id, body, suggested_text,
              status, reviewed_at, reviewer_device_id, points_awarded, created_at
         FROM knowledge_point_corrections
        WHERE status = 'pending'
        ORDER BY created_at ASC
        LIMIT $1 OFFSET $2`,
      [safeLimit, safeOffset],
    );
    return result.rows.map(toCorrectionDto);
  } catch (error) {
    throw toPgError(error);
  }
}
