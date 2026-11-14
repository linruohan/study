import { pool } from '../db.js';
import { HttpError } from '../http/errors.js';
import type { ChapterDto, ChapterRef } from './chapter.types.js';

interface ChapterRow {
  concept_id: string;
  age_band_id: string;
  degree_id: string;
  point_position: number;
  chapter_position: number;
  title: string;
  content: string | null;
}

function toPgError(error: unknown): unknown {
  const code = (error as { code?: string }).code;
  if (code === '23503') {
    return new HttpError(400, 'unknown_reference', '知识点不存在，无法添加章节');
  }
  if (code === '42P01') {
    return new HttpError(503, 'migration_required', '章节功能尚未启用，请先执行数据库迁移');
  }
  return error;
}

async function assertPointExists(ref: ChapterRef): Promise<void> {
  const result = await pool.query(
    `SELECT 1 FROM knowledge_variant_points
      WHERE concept_id = $1 AND age_band_id = $2 AND degree_id = $3 AND position = $4`,
    [ref.conceptId, ref.ageBandId, ref.degreeId, ref.pointPosition],
  );
  if (result.rowCount === 0) {
    throw new HttpError(404, 'not_found', '知识点不存在');
  }
}

export async function listChapters(ref: ChapterRef): Promise<ChapterDto[]> {
  await assertPointExists(ref);
  try {
    const result = await pool.query<ChapterRow>(
      `SELECT concept_id, age_band_id, degree_id, point_position, chapter_position, title, content
         FROM knowledge_variant_point_chapters
        WHERE concept_id = $1 AND age_band_id = $2 AND degree_id = $3 AND point_position = $4
        ORDER BY chapter_position`,
      [ref.conceptId, ref.ageBandId, ref.degreeId, ref.pointPosition],
    );
    return result.rows.map((row) => ({ chapterPosition: row.chapter_position, title: row.title, content: row.content }));
  } catch (error) {
    throw toPgError(error);
  }
}

export async function addChapter(ref: ChapterRef, chapter: ChapterDto): Promise<ChapterDto & { chapterPosition: number }> {
  await assertPointExists(ref);
  try {
    const result = await pool.query<{ chapter_position: number; title: string; content: string | null }>(
      `INSERT INTO knowledge_variant_point_chapters
         (concept_id, age_band_id, degree_id, point_position, chapter_position, title, content)
       SELECT $1, $2, $3, $4,
              COALESCE((SELECT max(chapter_position) + 1
                          FROM knowledge_variant_point_chapters
                         WHERE concept_id = $1 AND age_band_id = $2 AND degree_id = $3 AND point_position = $4), 1),
              $5, $6
       RETURNING chapter_position, title, content`,
      [ref.conceptId, ref.ageBandId, ref.degreeId, ref.pointPosition, chapter.title, chapter.content ?? null],
    );
    const row = result.rows[0];
    return { chapterPosition: row.chapter_position, title: row.title, content: row.content };
  } catch (error) {
    throw toPgError(error);
  }
}

/// 供知识库整包加载使用；表不存在时返回空数组。
export async function loadAllChapters(): Promise<ChapterRow[]> {
  try {
    const result = await pool.query<ChapterRow>(
      `SELECT concept_id, age_band_id, degree_id, point_position, chapter_position, title, content
         FROM knowledge_variant_point_chapters
        ORDER BY chapter_position`,
    );
    return result.rows;
  } catch (error) {
    if ((error as { code?: string }).code === '42P01') {
      return [];
    }
    throw error;
  }
}

export async function updateChapter(
  ref: ChapterRef,
  chapterPosition: number,
  chapter: { title: string; content: string | null },
): Promise<ChapterDto & { chapterPosition: number }> {
  await assertPointExists(ref);
  try {
    const result = await pool.query<{ chapter_position: number; title: string; content: string | null }>(
      `UPDATE knowledge_variant_point_chapters
          SET title = $6, content = $7
        WHERE concept_id = $1 AND age_band_id = $2 AND degree_id = $3 AND point_position = $4 AND chapter_position = $5
      RETURNING chapter_position, title, content`,
      [ref.conceptId, ref.ageBandId, ref.degreeId, ref.pointPosition, chapterPosition, chapter.title, chapter.content],
    );
    const row = result.rows[0];
    if (!row) throw new HttpError(404, 'not_found', '章节不存在');
    return { chapterPosition: row.chapter_position, title: row.title, content: row.content };
  } catch (error) {
    throw toPgError(error);
  }
}

export async function deleteChapter(ref: ChapterRef, chapterPosition: number): Promise<void> {
  await assertPointExists(ref);
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const del = await client.query(
      `DELETE FROM knowledge_variant_point_chapters
        WHERE concept_id = $1 AND age_band_id = $2 AND degree_id = $3 AND point_position = $4 AND chapter_position = $5`,
      [ref.conceptId, ref.ageBandId, ref.degreeId, ref.pointPosition, chapterPosition],
    );
    if (del.rowCount === 0) throw new HttpError(404, 'not_found', '章节不存在');
    await client.query(
      `UPDATE knowledge_variant_point_chapters
          SET chapter_position = chapter_position - 1
        WHERE concept_id = $1 AND age_band_id = $2 AND degree_id = $3 AND point_position = $4 AND chapter_position > $5`,
      [ref.conceptId, ref.ageBandId, ref.degreeId, ref.pointPosition, chapterPosition],
    );
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw toPgError(error);
  } finally {
    client.release();
  }
}
