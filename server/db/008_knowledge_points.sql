-- 三档知识点：按客户端 ConceptVariant.pointsFor 的默认规则展开。
--
--   入门 = 是什么、做什么
--   熟悉 = 想一想、参考回应
--   精通 = 我能……、一句说明（说明为空时只有一句）
--
-- 以后某个概念需要显式知识点时，新增编号更大的迁移文件写入；
-- 用同样的 ON CONFLICT 覆盖这里的默认展开值即可。

WITH derived AS (
  SELECT
    v.concept_id,
    v.age_band_id,
    p.degree_id,
    p.position,
    p.point
  FROM knowledge_variants v
  CROSS JOIN LATERAL (
    VALUES
      ('beginner', 1, v.topic),
      ('beginner', 2, v.doing),
      ('familiar', 1, v.check_question),
      ('familiar', 2, v.answer),
      ('advanced', 1, v.praise)
  ) AS p(degree_id, position, point)

  UNION ALL

  SELECT
    v.concept_id,
    v.age_band_id,
    'advanced',
    2,
    v.note
  FROM knowledge_variants v
  WHERE v.note IS NOT NULL
)
INSERT INTO knowledge_variant_points
  (concept_id, age_band_id, degree_id, position, point)
SELECT concept_id, age_band_id, degree_id, position, point
FROM derived
ON CONFLICT (concept_id, age_band_id, degree_id, position) DO UPDATE SET
  point = EXCLUDED.point;
