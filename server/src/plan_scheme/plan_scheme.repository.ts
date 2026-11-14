import { pool, type PoolClient } from '../db.js';
import { HttpError } from '../http/errors.js';
import type {
  PlanSchemeDimensionDto,
  PlanSchemeDto,
  PlanSchemeItemDto,
} from './plan_scheme.types.js';

/// 方案行。
interface SchemeRow {
  id: string;
  name: string;
  stage: string;
  stage_sort: number;
  sort_order: number;
  description: string;
  is_builtin: boolean;
  owner_user_id: string | null;
}

/// 创建/更新时的维度与条目载荷。
export interface DimensionInput {
  name: string;
  items: {
    content: string;
    expectedLevel?: string;
    conceptId?: string | null;
  }[];
}

/// 内置方案是公共内容；自建方案只有创建者本人可见可改。
export const BUILTIN_STAGES = [
  'mengxue',
  'primary',
  'junior',
  'senior',
  'college',
  'graduate',
  'master',
] as const;

function toSchemeDto(row: SchemeRow, dimensions: PlanSchemeDimensionDto[]): PlanSchemeDto {
  return {
    id: row.id,
    name: row.name,
    stage: row.stage as PlanSchemeDto['stage'],
    stageSort: row.stage_sort,
    sortOrder: row.sort_order,
    description: row.description,
    isBuiltin: row.is_builtin,
    ownerUserId: row.owner_user_id,
    dimensions,
  };
}

/// 迁移未执行时给 503，让客户端提示先迁移。
function translateDbError(error: unknown): never | void {
  const code = (error as { code?: string }).code;
  if (code === '42P01' || code === '42703') {
    const err = new Error('migration_required') as Error & { statusCode?: number; code?: string };
    err.statusCode = 503;
    err.code = 'migration_required';
    throw err;
  }
}

/// 读方案列表（不含维度条目）：内置方案 + 本人自建方案。
export async function listPlanSchemes(userId: string | null): Promise<PlanSchemeDto[]> {
  try {
    const result = await pool.query<SchemeRow>(
      `SELECT id, name, stage, stage_sort, sort_order, description, is_builtin, owner_user_id
       FROM plan_schemes
       WHERE is_builtin = true OR owner_user_id = $1
       ORDER BY stage_sort, sort_order, created_at`,
      [userId],
    );
    return result.rows.map((row) => toSchemeDto(row, []));
  } catch (error) {
    translateDbError(error);
    throw error;
  }
}

/// 判断方案是否对当前用户可读：内置方案公开，自建方案仅 owner。
async function schemeRowForRead(id: string, userId: string | null): Promise<SchemeRow> {
  const result = await pool.query<SchemeRow>(
    `SELECT id, name, stage, stage_sort, sort_order, description, is_builtin, owner_user_id
     FROM plan_schemes WHERE id = $1`,
    [id],
  );
  if (result.rows.length === 0) {
    throw new HttpError(404, 'not_found', '方案不存在');
  }
  const row = result.rows[0];
  if (!row.is_builtin && row.owner_user_id !== userId) {
    throw new HttpError(404, 'not_found', '方案不存在');
  }
  return row;
}

/// 读方案详情：维度 + 条目（条目带关联概念概要）。
export async function getPlanScheme(id: string, userId: string | null): Promise<PlanSchemeDto> {
  try {
    const row = await schemeRowForRead(id, userId);
    const dimensionResult = await pool.query(
      `SELECT id, name, sort_order FROM plan_scheme_dimensions
       WHERE scheme_id = $1 ORDER BY sort_order`,
      [id],
    );
    const itemResult = await pool.query(
      `SELECT i.id, i.dimension_id, i.content, i.expected_level, i.concept_id, i.sort_order,
              v.topic AS concept_topic
       FROM plan_scheme_items i
       LEFT JOIN knowledge_variants v
         ON v.concept_id = i.concept_id AND v.age_band_id = 'toddler'
       WHERE i.dimension_id IN (SELECT id FROM plan_scheme_dimensions WHERE scheme_id = $1)
       ORDER BY i.dimension_id, i.sort_order`,
      [id],
    );
    const itemsByDimension = new Map<string, PlanSchemeItemDto[]>();
    for (const item of itemResult.rows) {
      const list = itemsByDimension.get(item.dimension_id) ?? [];
      list.push({
        id: item.id,
        content: item.content,
        expectedLevel: item.expected_level,
        conceptId: item.concept_id,
        conceptTopic: item.concept_topic ?? null,
        sortOrder: item.sort_order,
      });
      itemsByDimension.set(item.dimension_id, list);
    }
    const dimensions: PlanSchemeDimensionDto[] = dimensionResult.rows.map((dim) => ({
      id: dim.id,
      name: dim.name,
      sortOrder: dim.sort_order,
      items: itemsByDimension.get(dim.id) ?? [],
    }));
    return toSchemeDto(row, dimensions);
  } catch (error) {
    translateDbError(error);
    throw error;
  }
}

/// 把一批参数列表拼成多行 INSERT 执行；分批避免单条语句参数超过上限。
async function insertBatches(
  client: PoolClient,
  sql: string,
  columnsPerRow: number,
  rows: unknown[][],
): Promise<void> {
  const batchSize = Math.max(1, Math.floor(65_000 / columnsPerRow));
  for (let start = 0; start < rows.length; start += batchSize) {
    const batch = rows.slice(start, start + batchSize);
    const values: unknown[] = [];
    const placeholders = batch
      .map((row) => {
        const rowPlaceholders = row.map((value) => {
          values.push(value);
          return `$${values.length}`;
        });
        return `(${rowPlaceholders.join(', ')})`;
      })
      .join(', ');
    await client.query(`${sql} VALUES ${placeholders}`, values);
  }
}

/// 在调用方事务内写入方案的维度与条目（先删后插，整批多行 INSERT）。
/// 事务的 BEGIN/COMMIT 由外层负责，这样基本信息和维度写入要么都成功要么都回滚。
async function writeDimensions(
  client: PoolClient,
  schemeId: string,
  dimensions: DimensionInput[],
): Promise<void> {
  try {
    await client.query('DELETE FROM plan_scheme_dimensions WHERE scheme_id = $1', [schemeId]);
    const dimensionRows = dimensions.map((dimension, d) => [
      `schm_own_${schemeId}_${d + 1}`,
      schemeId,
      dimension.name,
      d + 1,
    ]);
    if (dimensionRows.length > 0) {
      await insertBatches(
        client,
        `INSERT INTO plan_scheme_dimensions (id, scheme_id, name, sort_order)`,
        4,
        dimensionRows,
      );
    }
    const itemRows: unknown[][] = [];
    for (let d = 0; d < dimensions.length; d += 1) {
      const dimensionId = `schm_own_${schemeId}_${d + 1}`;
      const items = dimensions[d].items;
      for (let i = 0; i < items.length; i += 1) {
        const item = items[i];
        itemRows.push([
          `schi_own_${schemeId}_${d + 1}_${i + 1}`,
          dimensionId,
          item.content,
          item.expectedLevel ?? '',
          item.conceptId ?? null,
          i + 1,
        ]);
      }
    }
    if (itemRows.length > 0) {
      await insertBatches(
        client,
        `INSERT INTO plan_scheme_items (id, dimension_id, content, expected_level, concept_id, sort_order)`,
        6,
        itemRows,
      );
    }
  } catch (error) {
    // 条目关联了不存在的概念时给 400，而不是让外键错误变 500。
    if ((error as { code?: string }).code === '23503') {
      throw new HttpError(400, 'invalid_request', '关联的知识概念不存在');
    }
    throw error;
  }
}

/// 创建自建方案（基本信息 + 维度条目在同一个事务里，失败不留孤儿方案）。
export async function createPlanScheme(
  userId: string,
  input: { name: string; stage: string; description: string; dimensions: DimensionInput[] },
): Promise<PlanSchemeDto> {
  const client = await pool.connect();
  try {
    const id = `scheme_u_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`;
    await client.query('BEGIN');
    await client.query(
      `INSERT INTO plan_schemes (id, name, stage, stage_sort, sort_order, description, is_builtin, owner_user_id)
       VALUES ($1, $2, $3, 9, 0, $4, false, $5)`,
      [id, input.name, input.stage, input.description, userId],
    );
    await writeDimensions(client, id, input.dimensions);
    await client.query('COMMIT');
    return await getPlanScheme(id, userId);
  } catch (error) {
    await client.query('ROLLBACK').catch(() => undefined);
    translateDbError(error);
    throw error;
  } finally {
    client.release();
  }
}

/// 更新自建方案（仅 owner）：基本信息 + 整体替换维度/条目，同一事务完成。
export async function updatePlanScheme(
  id: string,
  userId: string,
  input: { name: string; stage: string; description: string; dimensions: DimensionInput[] },
): Promise<PlanSchemeDto> {
  const client = await pool.connect();
  try {
    const existing = await client.query<SchemeRow>(
      `SELECT id, is_builtin, owner_user_id FROM plan_schemes WHERE id = $1`,
      [id],
    );
    if (existing.rows.length === 0) {
      throw new HttpError(404, 'not_found', '方案不存在');
    }
    const row = existing.rows[0];
    if (row.is_builtin || row.owner_user_id !== userId) {
      throw new HttpError(403, 'forbidden', '只能修改自己的方案');
    }
    await client.query('BEGIN');
    await client.query(
      `UPDATE plan_schemes SET name = $1, stage = $2, description = $3 WHERE id = $4`,
      [input.name, input.stage, input.description, id],
    );
    await writeDimensions(client, id, input.dimensions);
    await client.query('COMMIT');
    return await getPlanScheme(id, userId);
  } catch (error) {
    await client.query('ROLLBACK').catch(() => undefined);
    translateDbError(error);
    throw error;
  } finally {
    client.release();
  }
}

/// 删除自建方案（仅 owner）；内置方案不可删。
export async function deletePlanScheme(id: string, userId: string): Promise<void> {
  try {
    const existing = await pool.query<SchemeRow>(
      `SELECT id, is_builtin, owner_user_id FROM plan_schemes WHERE id = $1`,
      [id],
    );
    if (existing.rows.length === 0) {
      throw new HttpError(404, 'not_found', '方案不存在');
    }
    const row = existing.rows[0];
    if (row.is_builtin || row.owner_user_id !== userId) {
      throw new HttpError(403, 'forbidden', '只能删除自己的方案');
    }
    await pool.query('DELETE FROM plan_schemes WHERE id = $1', [id]);
  } catch (error) {
    translateDbError(error);
    throw error;
  }
}

/// 复制方案为本人自建（空白创建之外的另一种起步方式）；复制动作在同一个事务里完成。
export async function clonePlanScheme(id: string, userId: string): Promise<PlanSchemeDto> {
  const source = await getPlanScheme(id, userId);
  const client = await pool.connect();
  try {
    // 内置方案副本加后缀便于区分；自建方案副本沿用原名。
    const newId = `scheme_u_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`;
    const name = source.isBuiltin ? `${source.name}（副本）` : source.name;
    await client.query('BEGIN');
    await client.query(
      `INSERT INTO plan_schemes (id, name, stage, stage_sort, sort_order, description, is_builtin, owner_user_id)
       VALUES ($1, $2, $3, 9, 0, $4, false, $5)`,
      [newId, name, source.stage, source.description, userId],
    );
    await writeDimensions(
      client,
      newId,
      source.dimensions.map((dimension) => ({
        name: dimension.name,
        items: dimension.items.map((item) => ({
          content: item.content,
          expectedLevel: item.expectedLevel,
          conceptId: item.conceptId,
        })),
      })),
    );
    await client.query('COMMIT');
    return await getPlanScheme(newId, userId);
  } catch (error) {
    await client.query('ROLLBACK').catch(() => undefined);
    translateDbError(error);
    throw error;
  } finally {
    client.release();
  }
}
