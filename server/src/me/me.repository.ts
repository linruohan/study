import { pool } from '../db.js';
import { HttpError } from '../http/errors.js';
import type { PlanDto, UserDataDto } from './me.types.js';

/// 设置行。
interface ProfileRow {
  age_band_id: string | null;
  focus_domain_id: string | null;
}

/// 计划行。
interface PlanRow {
  id: string;
  domain_id: string;
  depth: 'brief' | 'deep';
  concept_id: string | null;
  degree_id: string | null;
  start_at: Date;
  remind: boolean;
  done: boolean;
  reminded_at: Date | null;
  snoozed_until: Date | null;
}

/// 学习记录行。
interface RecordRow {
  id: string;
  at: Date;
  source: string;
  subject: string;
  body: string;
  concept_id: string | null;
  domain_id: string | null;
  age_band_id: string | null;
}

/// 登记设备；已存在时只更新最后访问时间。
async function touchDevice(deviceId: string): Promise<void> {
  await pool.query(
    `INSERT INTO devices (id, last_seen_at)
     VALUES ($1, now())
     ON CONFLICT (id) DO UPDATE SET last_seen_at = now()`,
    [deviceId],
  );
}

/// 读取一台设备的全部业务数据；没有数据时返回空结构。
export async function loadUserData(deviceId: string): Promise<UserDataDto> {
  await touchDevice(deviceId);

  const [profileResult, plansResult, recordsResult] = await Promise.all([
    pool.query<ProfileRow>(
      'SELECT age_band_id, focus_domain_id FROM study_profiles WHERE device_id = $1',
      [deviceId],
    ),
    pool.query<PlanRow>(
      `SELECT id, domain_id, depth, concept_id, degree_id, start_at,
              remind, done, reminded_at, snoozed_until
         FROM study_plans
        WHERE device_id = $1
        ORDER BY start_at`,
      [deviceId],
    ),
    pool.query<RecordRow>(
      `SELECT id, at, source, subject, body, concept_id, domain_id, age_band_id
         FROM learning_records
        WHERE device_id = $1
        ORDER BY at`,
      [deviceId],
    ),
  ]);

  const profile = profileResult.rows[0];
  return {
    profile: {
      band: profile?.age_band_id ?? null,
      focusDomainId: profile?.focus_domain_id ?? null,
    },
    plans: plansResult.rows.map(toPlanDto),
    records: recordsResult.rows.map(toRecordDto),
  };
}

/// 用客户端整份快照替换一台设备的数据，事务内完成，失败全部回滚。
export async function saveUserData(
  deviceId: string,
  data: UserDataDto,
): Promise<UserDataDto> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(
      `INSERT INTO devices (id, last_seen_at)
       VALUES ($1, now())
       ON CONFLICT (id) DO UPDATE SET last_seen_at = now()`,
      [deviceId],
    );

    await client.query(
      `INSERT INTO study_profiles (device_id, age_band_id, focus_domain_id)
       VALUES ($1, $2, $3)
       ON CONFLICT (device_id) DO UPDATE SET
         age_band_id = EXCLUDED.age_band_id,
         focus_domain_id = EXCLUDED.focus_domain_id`,
      [deviceId, data.profile.band, data.profile.focusDomainId],
    );

    await client.query('DELETE FROM study_plans WHERE device_id = $1', [deviceId]);
    for (const plan of data.plans) {
      await client.query(
        `INSERT INTO study_plans
           (device_id, id, domain_id, depth, concept_id, degree_id, start_at,
            remind, done, reminded_at, snoozed_until)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
        [
          deviceId,
          plan.id,
          plan.domainId,
          plan.depth,
          plan.conceptId,
          plan.degree,
          plan.startAt,
          plan.remind,
          plan.done,
          plan.remindedAt,
          plan.snoozedUntil,
        ],
      );
    }

    await client.query('DELETE FROM learning_records WHERE device_id = $1', [
      deviceId,
    ]);
    for (const record of data.records) {
      await client.query(
        `INSERT INTO learning_records
           (device_id, id, at, source, subject, body, concept_id, domain_id, age_band_id)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
        [
          deviceId,
          record.id,
          record.at,
          record.source,
          record.subject,
          record.body,
          record.conceptId,
          record.domainId,
          record.ageBandId,
        ],
      );
    }

    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    // 引用了不存在的知识 id 时给 400，避免把外键错误当成服务故障。
    const code = (error as { code?: string }).code;
    if (code === '23503') {
      throw new HttpError(400, 'unknown_reference', '计划或记录引用了不存在的知识');
    }
    throw error;
  } finally {
    client.release();
  }

  return loadUserData(deviceId);
}

/// 数据库行转接口结构。
function toPlanDto(row: PlanRow): PlanDto {
  return {
    id: row.id,
    domainId: row.domain_id,
    depth: row.depth,
    conceptId: row.concept_id,
    degree: row.degree_id,
    startAt: row.start_at.toISOString(),
    remind: row.remind,
    done: row.done,
    remindedAt: row.reminded_at?.toISOString() ?? null,
    snoozedUntil: row.snoozed_until?.toISOString() ?? null,
  };
}

/// 数据库行转接口结构。
function toRecordDto(row: RecordRow): UserDataDto['records'][number] {
  return {
    id: row.id,
    at: row.at.toISOString(),
    source: row.source,
    subject: row.subject,
    body: row.body,
    conceptId: row.concept_id,
    domainId: row.domain_id,
    ageBandId: row.age_band_id,
  };
}
