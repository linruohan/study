import { pool } from '../db.js';
import { HttpError } from '../http/errors.js';
import type {
  AgeBandDto,
  CategoryDto,
  ConceptDto,
  DegreeDto,
  DomainDto,
  KnowledgeBundle,
  SageCredits,
  VariantDto,
} from './knowledge.types.js';
import { loadSageCredits } from './sage.repository.js';
import { loadAllChapters } from './chapter.repository.js';

/// 年龄段行。
interface AgeBandRow {
  id: string;
  label: string;
  short_label: string;
  how_to_learn: string;
  shows_subject_names: boolean;
}

/// 学习程度行。
interface DegreeRow {
  id: string;
  label: string;
}

/// 九类分类行。
interface CategoryRow {
  id: string;
  parent_id: string | null;
  name: string;
  question: string;
  ancient: string;
  modern: string;
  glyph: string;
  color: string;
}

/// 领域行。
interface DomainRow {
  id: string;
  name: string;
  glyph: string;
  color: string;
  category_id: string;
}

/// 概念行。
interface ConceptRow {
  id: string;
  domain_id: string;
  depth: number;
}

/// 前置依赖行。
interface PrerequisiteRow {
  concept_id: string;
  prerequisite_id: string;
}

/// 分龄呈现行。
interface VariantRow {
  concept_id: string;
  age_band_id: string;
  topic: string;
  glyph: string | null;
  doing: string;
  praise: string;
  check_question: string;
  answer: string;
  note: string | null;
}

/// 知识点行。
interface PointRow {
  concept_id: string;
  age_band_id: string;
  degree_id: string;
  point: string;
}

/// 读取完整知识库，按「年龄段 → 程度 → 分类 → 领域 → 概念 → 呈现 → 知识点」组装。
export async function loadKnowledgeBundle(): Promise<KnowledgeBundle> {
  const [
    ageBandsResult,
    degreesResult,
    domainsResult,
    conceptsResult,
    prerequisitesResult,
    variantsResult,
    pointsResult,
  ] = await Promise.all([
    pool.query<AgeBandRow>(
      `SELECT id, label, short_label, how_to_learn, shows_subject_names
         FROM knowledge_age_bands
        ORDER BY sort_order`,
    ),
    pool.query<DegreeRow>(
      'SELECT id, label FROM knowledge_degrees ORDER BY sort_order',
    ),
    pool.query<DomainRow>(
      `SELECT id, name, glyph, color, category_id
         FROM knowledge_domains
        ORDER BY sort_order`,
    ),
    pool.query<ConceptRow>(
      `SELECT c.id, c.domain_id, c.depth
         FROM knowledge_concepts c
         JOIN knowledge_domains d ON d.id = c.domain_id
        ORDER BY d.sort_order, c.depth, c.sort_order`,
    ),
    pool.query<PrerequisiteRow>(
      'SELECT concept_id, prerequisite_id FROM knowledge_concept_prerequisites',
    ),
    pool.query<VariantRow>(
      `SELECT v.concept_id, v.age_band_id, v.topic, v.glyph, v.doing,
              v.praise, v.check_question, v.answer, v.note
         FROM knowledge_variants v
         JOIN knowledge_age_bands b ON b.id = v.age_band_id
        ORDER BY b.sort_order`,
    ),
    pool.query<PointRow>(
      `SELECT concept_id, age_band_id, degree_id, point
         FROM knowledge_variant_points
        ORDER BY degree_id, position`,
    ),
  ]);

  let categoriesResult;
  try {
    categoriesResult = await pool.query<CategoryRow>(
      `SELECT id, parent_id, name, question, ancient, modern, glyph, color
         FROM knowledge_categories
        ORDER BY sort_order`,
    );
  } catch {
    categoriesResult = await pool.query<any>(
      `SELECT id, name, question, ancient, modern, glyph, color
         FROM knowledge_categories
        ORDER BY sort_order`,
    );
  }

  const ageBands: AgeBandDto[] = ageBandsResult.rows.map((row) => ({
    id: row.id,
    label: row.label,
    shortLabel: row.short_label,
    howToLearn: row.how_to_learn,
    showsSubjectNames: row.shows_subject_names,
  }));

  const degrees: DegreeDto[] = degreesResult.rows.map((row) => ({
    id: row.id,
    label: row.label,
  }));

  const categories: CategoryDto[] = (categoriesResult.rows as Array<CategoryRow & { parent_id?: string | null }>).map((row) => ({
    id: row.id,
    parentId: row.parent_id ?? null,
    name: row.name,
    question: row.question,
    ancient: row.ancient,
    modern: row.modern,
    glyph: row.glyph,
    color: row.color,
  }));

  const domains: DomainDto[] = domainsResult.rows.map((row) => ({
    id: row.id,
    name: row.name,
    glyph: row.glyph,
    color: row.color,
    categoryId: row.category_id,
    concepts: [],
  }));

  // 两处都按 id 建索引，后面按行挂载，避免循环里反复查找。
  const domainById = new Map(domains.map((domain) => [domain.id, domain]));
  const conceptById = new Map<string, ConceptDto>();

  for (const row of conceptsResult.rows) {
    const concept: ConceptDto = {
      id: row.id,
      depth: row.depth,
      prerequisites: [],
      variants: {},
    };
    conceptById.set(row.id, concept);
    domainById.get(row.domain_id)?.concepts.push(concept);
  }

  for (const row of prerequisitesResult.rows) {
    conceptById.get(row.concept_id)?.prerequisites.push(row.prerequisite_id);
  }

  const variantByKey = new Map<string, VariantDto>();
  for (const row of variantsResult.rows) {
    const variant: VariantDto = {
      topic: row.topic,
      glyph: row.glyph,
      doing: row.doing,
      praise: row.praise,
      check: row.check_question,
      answer: row.answer,
      note: row.note,
      points: {},
    };
    variantByKey.set(`${row.concept_id}:${row.age_band_id}`, variant);
    const concept = conceptById.get(row.concept_id);
    if (concept) {
      concept.variants[row.age_band_id] = variant;
    }
  }

  for (const row of pointsResult.rows) {
    const variant = variantByKey.get(`${row.concept_id}:${row.age_band_id}`);
    if (!variant) {
      continue;
    }
    (variant.points[row.degree_id] ??= []).push(row.point);
  }

  const chapters = await loadAllChapters();
  for (const row of chapters) {
    const variant = variantByKey.get(`${row.concept_id}:${row.age_band_id}`);
    if (!variant) {
      continue;
    }
    variant.chapters ??= {};
    const byDegree = (variant.chapters[row.degree_id] ??= {});
    const key = String(row.point_position);
    (byDegree[key] ??= []).push({ chapterPosition: row.chapter_position, title: row.title, content: row.content });
  }

  return { ageBands, degrees, categories, domains, sageCredits: await loadSageCredits() };
}

export interface CreateDomainInput {
  id?: string;
  categoryId: string;
  name: string;
  glyph?: string;
  color?: string;
}

/// 在某个分类下创建学习领域；id 留空时由服务端生成，界面可直接新建。
export async function createDomain(input: CreateDomainInput): Promise<DomainDto> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    // 领域必须挂在真实存在的分类下，否则知识库树会断掉。
    const category = await client.query(
      'SELECT 1 FROM knowledge_categories WHERE id = $1',
      [input.categoryId],
    );
    if (category.rowCount === 0) {
      const err = new Error('category_not_found') as Error & { statusCode?: number; code?: string };
      err.statusCode = 404;
      err.code = 'not_found';
      throw err;
    }
    // 新领域排在所属分类现有领域之后。
    const sort = await client.query<{ n: number }>(
      `SELECT COALESCE(max(sort_order), 0) + 1 AS n FROM knowledge_domains WHERE category_id = $1`,
      [input.categoryId],
    );
    const sortOrder = sort.rows[0]?.n ?? 1;
    const result = await client.query<DomainRow>(
      `INSERT INTO knowledge_domains (id, name, glyph, color, category_id, sort_order)
       VALUES (COALESCE($1, 'sage_d_' || substr(gen_random_uuid()::text, 1, 8)), $2, $3, $4, $5, $6)
       RETURNING id, name, glyph, color, category_id`,
      [
        input.id ?? null,
        input.name,
        input.glyph ?? '域',
        input.color ?? '#7A6A54',
        input.categoryId,
        sortOrder,
      ],
    );
    await client.query('COMMIT');
    const row = result.rows[0];
    return {
      id: row.id,
      name: row.name,
      glyph: row.glyph,
      color: row.color,
      categoryId: row.category_id,
      concepts: [],
    };
  } catch (error) {
    await client.query('ROLLBACK');
    if ((error as Error).message === 'category_not_found') {
      throw error;
    }
    const code = (error as { code?: string }).code;
    if (code === '23505') {
      const err = new Error('duplicate') as Error & { statusCode?: number; code?: string };
      err.statusCode = 409;
      err.code = 'conflict';
      throw err;
    }
    if (code === '23503') {
      const err = new Error('category_not_found') as Error & { statusCode?: number; code?: string };
      err.statusCode = 404;
      err.code = 'not_found';
      throw err;
    }
    throw error;
  } finally {
    client.release();
  }
}

export interface CreateConceptInput {
  domainId: string;
  ageBandId: string;
  topic: string;
  doing?: string;
  praise?: string;
  check?: string;
  answer?: string;
  note?: string;
  glyph?: string | null;
}

/// 在某个领域下创建一条知识：概念节点 + 当前年龄档呈现 + 三档默认知识点。
///
/// 知识库页面用它统一管理知识；不依赖智者贡献流程。
export async function createConcept(
  input: CreateConceptInput,
): Promise<{ id: string; depth: number }> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    // 领域与年龄档必须真实存在，否则知识挂不上去。
    const reference = await client.query<{ domain: string; band: string }>(
      `SELECT
         (SELECT 1 FROM knowledge_domains WHERE id = $1) AS domain,
         (SELECT 1 FROM knowledge_age_bands WHERE id = $2) AS band`,
      [input.domainId, input.ageBandId],
    );
    const refs = reference.rows[0];
    if (!refs || refs.domain == null || refs.band == null) {
      throw new HttpError(400, 'unknown_reference', '领域或年龄档不存在');
    }

    // 新知识排在领域现有最深一层之后，保证默认学习顺序。
    const created = await client.query<{ id: string; depth: number }>(
      `INSERT INTO knowledge_concepts (id, domain_id, depth, sort_order)
       SELECT 'k_' || substr(gen_random_uuid()::text, 1, 10), $1,
              COALESCE((SELECT max(depth) + 1 FROM knowledge_concepts WHERE domain_id = $1), 0),
              COALESCE((SELECT max(sort_order) + 1 FROM knowledge_concepts WHERE domain_id = $1), 1)
       RETURNING id, depth`,
      [input.domainId],
    );
    const concept = created.rows[0];

    const doing = input.doing?.trim() || input.topic;
    const praise = input.praise?.trim() || doing;
    const check = input.check?.trim() || input.topic;
    const answer = input.answer?.trim() || input.note?.trim() || doing;
    const note = input.note?.trim() || null;

    // 本档呈现：符号缺省时沿用领域符号。
    await client.query(
      `INSERT INTO knowledge_variants
         (concept_id, age_band_id, topic, glyph, doing, praise, check_question, answer, note)
       SELECT $1, $2, $3, COALESCE($4, d.glyph), $5, $6, $7, $8, $9
         FROM knowledge_domains d
        WHERE d.id = $10`,
      [concept.id, input.ageBandId, input.topic, input.glyph ?? null, doing, praise, check, answer, note, input.domainId],
    );

    // 三档默认知识点与种子数据规则一致；之后可在详情页继续追加。
    await client.query(
      `INSERT INTO knowledge_variant_points
         (concept_id, age_band_id, degree_id, position, point)
       VALUES
         ($1, $2, 'beginner', 1, $3),
         ($1, $2, 'beginner', 2, $4),
         ($1, $2, 'familiar', 1, $5),
         ($1, $2, 'familiar', 2, $6),
         ($1, $2, 'advanced', 1, $7)
       ON CONFLICT DO NOTHING`,
      [concept.id, input.ageBandId, input.topic, doing, check, answer, praise],
    );

    await client.query('COMMIT');
    return { id: concept.id, depth: concept.depth };
  } catch (error) {
    await client.query('ROLLBACK');
    const code = (error as { code?: string }).code;
    if (code === '23503') {
      throw new HttpError(400, 'unknown_reference', '领域或年龄档不存在');
    }
    throw error;
  } finally {
    client.release();
  }
}

export interface CreatePointInput {
  conceptId: string;
  ageBandId: string;
  degreeId: string;
  point: string;
}

/// 在某条知识、某个年龄档、某个学习程度下追加一个知识点。
///
/// 位置接在该程度现有知识点末尾，章节随后可以挂到这个位置上。
export async function addKnowledgePoint(
  input: CreatePointInput,
): Promise<{ position: number; point: string }> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    // 知识点必须挂在已存在的分龄呈现上。
    const variant = await client.query(
      'SELECT 1 FROM knowledge_variants WHERE concept_id = $1 AND age_band_id = $2',
      [input.conceptId, input.ageBandId],
    );
    if (variant.rowCount === 0) {
      throw new HttpError(404, 'not_found', '这条知识在这个年龄档还没有内容');
    }
    const next = await client.query<{ position: number }>(
      `SELECT COALESCE(max(position), 0) + 1 AS position
         FROM knowledge_variant_points
        WHERE concept_id = $1 AND age_band_id = $2 AND degree_id = $3`,
      [input.conceptId, input.ageBandId, input.degreeId],
    );
    const position = next.rows[0]?.position ?? 1;
    await client.query(
      `INSERT INTO knowledge_variant_points
         (concept_id, age_band_id, degree_id, position, point)
       VALUES ($1, $2, $3, $4, $5)`,
      [input.conceptId, input.ageBandId, input.degreeId, position, input.point],
    );
    await client.query('COMMIT');
    return { position, point: input.point };
  } catch (error) {
    await client.query('ROLLBACK');
    const code = (error as { code?: string }).code;
    if (code === '23503') {
      throw new HttpError(400, 'unknown_reference', '年龄档或学习程度不存在');
    }
    throw error;
  } finally {
    client.release();
  }
}

export interface CreateCategoryInput {
  id: string;
  parentId?: string | null;
  name: string;
  question: string;
  ancient?: string;
  modern?: string;
  glyph?: string;
  color?: string;
}

export interface UpdateCategoryInput {
  id: string;
  name: string;
  question: string;
}

/// 修改分类的名称与描述；分类不存在时返回 404。
export async function updateCategory(input: UpdateCategoryInput): Promise<CategoryDto> {
  const result = await pool.query<CategoryRow>(
    `UPDATE knowledge_categories
        SET name = $2, question = $3
      WHERE id = $1
      RETURNING id, parent_id, name, question, ancient, modern, glyph, color`,
    [input.id, input.name, input.question],
  );
  if (result.rowCount === 0) {
    const err = new Error('category_not_found') as Error & { statusCode?: number; code?: string };
    err.statusCode = 404;
    err.code = 'not_found';
    throw err;
  }
  const row = result.rows[0];
  return {
    id: row.id,
    parentId: row.parent_id,
    name: row.name,
    question: row.question,
    ancient: row.ancient,
    modern: row.modern,
    glyph: row.glyph,
    color: row.color,
  };
}

/// 创建知识分类/子类型（可嵌套）；需要已执行 012 迁移以支持 parent_id。
export async function createCategory(input: CreateCategoryInput): Promise<CategoryDto> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    if (input.parentId) {
      const parent = await client.query('SELECT 1 FROM knowledge_categories WHERE id = $1', [input.parentId]);
      if (parent.rowCount === 0) {
        const err = new Error('parent_not_found') as Error & { statusCode?: number; code?: string };
        err.statusCode = 404;
        err.code = 'not_found';
        throw err;
      }
    }
    const sort = await client.query<{ n: number }>(
      `SELECT COALESCE(max(sort_order), 0) + 1 AS n FROM knowledge_categories WHERE parent_id IS NOT DISTINCT FROM $1`,
      [input.parentId ?? null],
    );
    const sortOrder = sort.rows[0]?.n ?? 1;
    const result = await client.query<CategoryRow>(
      `INSERT INTO knowledge_categories (id, parent_id, name, question, ancient, modern, glyph, color, sort_order)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING id, parent_id, name, question, ancient, modern, glyph, color`,
      [
        input.id,
        input.parentId ?? null,
        input.name,
        input.question,
        input.ancient ?? '',
        input.modern ?? '',
        input.glyph ?? '类',
        input.color ?? '#7A6A54',
        sortOrder,
      ],
    );
    await client.query('COMMIT');
    const row = result.rows[0];
    return {
      id: row.id,
      parentId: row.parent_id,
      name: row.name,
      question: row.question,
      ancient: row.ancient,
      modern: row.modern,
      glyph: row.glyph,
      color: row.color,
    };
  } catch (error) {
    await client.query('ROLLBACK');
    const code = (error as { code?: string }).code;
    if (code === '42703') {
      const err = new Error('migration_required') as Error & { statusCode?: number; code?: string };
      err.statusCode = 503;
      err.code = 'migration_required';
      throw err;
    }
    if ((error as Error).message === 'parent_not_found') {
      throw error;
    }
    if (code === '23505') {
      const err = new Error('duplicate') as Error & { statusCode?: number; code?: string };
      err.statusCode = 409;
      err.code = 'conflict';
      throw err;
    }
    throw error;
  } finally {
    client.release();
  }
}
