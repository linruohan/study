import { pool } from '../db.js';
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
