import { pool } from '../db.js';
import { HttpError } from '../http/errors.js';
import type { ContributionDto, ContributionInput, SageCredits } from './sage.types.js';

/// 贡献行。
interface ContributionRow {
  id: string;
  kind: 'knowledge' | 'point';
  domain_id: string | null;
  age_band_id: string | null;
  degree_id: string | null;
  concept_id: string | null;
  position: number | null;
  topic: string;
  doing: string | null;
  note: string | null;
  status: 'pending' | 'approved';
  reviewed_at: Date | null;
  created_at: Date;
}

/// 智者名行。
interface SageRow {
  device_id: string;
  name: string;
}

/// 记录一条业务错误的通用出口：外键失败回 400，其余原样抛出。
function toHttpError(error: unknown): unknown {
  const code = (error as { code?: string }).code;
  if (code === '23503') {
    return new HttpError(400, 'unknown_reference', '领域、年龄档、程度或概念不存在');
  }
  if (code === '23514') {
    return new HttpError(400, 'invalid_request', '提交内容不完整');
  }
  return error;
}

/// 登记设备；已存在时只更新最后访问时间。
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

/// 读取一台设备的智者名；没写过返回 null。
export async function loadSageName(deviceId: string): Promise<string | null> {
  const result = await pool.query<SageRow>(
    'SELECT name FROM knowledge_sages WHERE device_id = $1',
    [deviceId],
  );
  return result.rows[0]?.name ?? null;
}

/// 写入或更新智者名；名字会跟随这台设备的全部贡献。
export async function saveSageName(deviceId: string, name: string): Promise<string> {
  await pool.query(
    `INSERT INTO devices (id, last_seen_at)
     VALUES ($1, now())
     ON CONFLICT (id) DO UPDATE SET last_seen_at = now()`,
    [deviceId],
  );
  await pool.query(
    `INSERT INTO knowledge_sages (device_id, name)
     VALUES ($1, $2)
     ON CONFLICT (device_id) DO UPDATE SET name = EXCLUDED.name`,
    [deviceId, name],
  );
  return name;
}

/// 一台设备的全部贡献，新的在前。
export async function listContributions(deviceId: string): Promise<ContributionDto[]> {
  const result = await pool.query<ContributionRow>(
    `SELECT id, kind, domain_id, age_band_id, degree_id, concept_id, position,
            topic, doing, note, status, reviewed_at, created_at
       FROM knowledge_contributions
      WHERE device_id = $1
      ORDER BY created_at DESC`,
    [deviceId],
  );
  return result.rows.map(toContributionDto);
}

/// 提交并自动审批一条贡献。
///
/// kind = knowledge：新建一个原子概念 + 本年龄档的呈现 + 三档知识点，
/// 前置为空，知识库里排在领域最深处。
/// kind = point：往已有概念在本年龄档的某档知识点后面追加一条。
export async function createContribution(
  deviceId: string,
  input: ContributionInput,
): Promise<ContributionDto> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await touchDevice(client, deviceId);

    // 016 迁移后「领域」层已并入分类树：客户端传的 domainId 是旧领域 id，
    // 迁移时领域 id 沿用为分类 id（撞名则加 cat_ 前缀），两种都接受。
    const reference = await client.query<{ category: string | null }>(
      `SELECT (
         SELECT id FROM knowledge_categories
          WHERE id = $1 OR id = 'cat_' || $1
          ORDER BY CASE WHEN id = $1 THEN 0 ELSE 1 END
          LIMIT 1
       ) AS category`,
      [input.domainId],
    );
    const categoryId = reference.rows[0]?.category ?? null;
    const band = await client.query('SELECT 1 FROM knowledge_age_bands WHERE id = $1', [
      input.ageBandId,
    ]);
    const degree = await client.query('SELECT 1 FROM knowledge_degrees WHERE id = $1', [
      input.degreeId,
    ]);
    if (!categoryId || band.rowCount === 0 || degree.rowCount === 0) {
      throw new HttpError(400, 'unknown_reference', '领域、年龄档或程度不存在');
    }

    const doing = input.doing?.trim() || null;
    const note = input.note?.trim() || null;

    let conceptId: string | null = null;
    let position: number | null = null;

    if (input.kind === 'knowledge') {
      // 新知识：id 用随机后缀避免冲突，深度排在分类当前最深处之后。
      const created = await client.query<{ id: string; depth: number; sort_order: number }>(
        `INSERT INTO knowledge_concepts (id, category_id, depth, sort_order)
         SELECT 'sage_' || substr(gen_random_uuid()::text, 1, 8), $1,
                COALESCE((SELECT max(depth) + 1 FROM knowledge_concepts WHERE category_id = $1), 0),
                COALESCE((SELECT max(sort_order) + 1 FROM knowledge_concepts WHERE category_id = $1), 1)
         RETURNING id, depth, sort_order`,
        [categoryId],
      );
      const concept = created.rows[0];
      conceptId = concept.id;

      // 本档呈现：缺省时用分类符号，提问与回应先用已知的内容占位。
      const variant = await client.query(
        `INSERT INTO knowledge_variants
           (concept_id, age_band_id, topic, glyph, doing, praise, check_question, answer, note)
         SELECT $1, $2, $3, c.glyph, $4, $4, $5, $5, $6
           FROM knowledge_categories c
          WHERE c.id = $7`,
        [conceptId, input.ageBandId, input.topic, doing ?? input.topic, note ?? doing ?? input.topic, note, categoryId],
      );
      if (variant.rowCount === 0) {
        throw new HttpError(400, 'unknown_reference', '领域不存在');
      }

      // 三档知识点按默认规则展开，界面即有内容可学。
      await client.query(
        `INSERT INTO knowledge_variant_points
           (concept_id, age_band_id, degree_id, position, point)
         VALUES
           ($1, $2, 'beginner', 1, $3),
           ($1, $2, 'beginner', 2, $4),
           ($1, $2, 'familiar', 1, $5),
           ($1, $2, 'familiar', 2, $5),
           ($1, $2, 'advanced', 1, $4)`,
        [
          conceptId,
          input.ageBandId,
          input.topic,
          doing ?? input.topic,
          note ?? doing ?? input.topic,
        ],
      );
    } else {
      // 知识点：必须挂在已有概念在本年龄档的呈现上，位置接在该档末尾。
      if (!input.conceptId) {
        throw new HttpError(400, 'invalid_request', '知识点要指明加在哪条知识上');
      }
      const variant = await client.query(
        'SELECT 1 FROM knowledge_variants WHERE concept_id = $1 AND age_band_id = $2',
        [input.conceptId, input.ageBandId],
      );
      if (variant.rowCount === 0) {
        throw new HttpError(400, 'unknown_reference', '这条知识在这一年龄档没有内容');
      }
      const next = await client.query<{ position: number }>(
        `SELECT COALESCE(max(position), 0) + 1 AS position
           FROM knowledge_variant_points
          WHERE concept_id = $1 AND age_band_id = $2 AND degree_id = $3`,
        [input.conceptId, input.ageBandId, input.degreeId],
      );
      position = next.rows[0]?.position ?? 1;
      await client.query(
        `INSERT INTO knowledge_variant_points
           (concept_id, age_band_id, degree_id, position, point)
         VALUES ($1, $2, $3, $4, $5)`,
        [input.conceptId, input.ageBandId, input.degreeId, position, input.topic],
      );
      conceptId = input.conceptId;
    }

    // 提交即审批：通过后写回贡献记录，留创建者与时间。
    const inserted = await client.query<ContributionRow>(
      `INSERT INTO knowledge_contributions
         (device_id, kind, domain_id, age_band_id, degree_id, concept_id, position,
          topic, doing, note, status, reviewed_at, applied_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 'approved', now(), now())
       RETURNING id, kind, domain_id, age_band_id, degree_id, concept_id, position,
                 topic, doing, note, status, reviewed_at, created_at`,
      [
        deviceId,
        input.kind,
        input.domainId,
        input.ageBandId,
        input.degreeId,
        conceptId,
        position,
        input.topic,
        doing,
        note,
      ],
    );

    await client.query('COMMIT');
    return toContributionDto(inserted.rows[0]);
  } catch (error) {
    await client.query('ROLLBACK');
    throw toHttpError(error);
  } finally {
    client.release();
  }
}

/// 汇总通过审批的贡献对应的创建者名。
///
/// knowledge 按 concept_id 归属；point 按概念+年龄档+程度+位置定位到具体知识点。
export async function loadSageCredits(): Promise<SageCredits> {
  const result = await pool.query<{
    kind: 'knowledge' | 'point';
    concept_id: string | null;
    age_band_id: string | null;
    degree_id: string | null;
    position: number | null;
    sage: string | null;
  }>(
    `SELECT c.kind, c.concept_id, c.age_band_id, c.degree_id, c.position, s.name AS sage
       FROM knowledge_contributions c
       JOIN knowledge_sages s ON s.device_id = c.device_id
      WHERE c.status = 'approved'
      ORDER BY c.created_at`,
  );

  const credits: SageCredits = { knowledge: {}, points: {} };
  for (const row of result.rows) {
    if (!row.sage) {
      continue;
    }
    if (row.kind === 'knowledge' && row.concept_id) {
      credits.knowledge[row.concept_id] = row.sage;
    } else if (row.kind === 'point' && row.concept_id && row.age_band_id && row.degree_id && row.position) {
      credits.points[`${row.concept_id}:${row.age_band_id}:${row.degree_id}:${row.position}`] = row.sage;
    }
  }
  return credits;
}

/// 数据库行转接口结构。
function toContributionDto(row: ContributionRow): ContributionDto {
  return {
    id: row.id,
    kind: row.kind,
    domainId: row.domain_id,
    ageBandId: row.age_band_id,
    degreeId: row.degree_id,
    conceptId: row.concept_id,
    position: row.position,
    topic: row.topic,
    doing: row.doing,
    note: row.note,
    status: row.status,
    reviewedAt: row.reviewed_at?.toISOString() ?? null,
    createdAt: row.created_at.toISOString(),
  };
}
