-- 数领域：从数实物到统计与微积分入门，深浅由 depth 表示。
-- 数据来源：app/lib/knowledge/catalog/math.dart，两边改动要同步。

INSERT INTO knowledge_domains
  (id, name, glyph, color, category_id, sort_order)
VALUES
  ('math', '数', '数', '#3E6F8C', 'cosmos', 2)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  glyph = EXCLUDED.glyph,
  color = EXCLUDED.color,
  category_id = EXCLUDED.category_id,
  sort_order = EXCLUDED.sort_order;

INSERT INTO knowledge_concepts (id, domain_id, depth, sort_order)
VALUES
  ('count_objects', 'math', 0, 1),
  ('fraction', 'math', 1, 2),
  ('statistics', 'math', 2, 3)
ON CONFLICT (id) DO UPDATE SET
  domain_id = EXCLUDED.domain_id,
  depth = EXCLUDED.depth,
  sort_order = EXCLUDED.sort_order;

INSERT INTO knowledge_concept_prerequisites (concept_id, prerequisite_id)
VALUES
  ('fraction', 'count_objects'),
  ('statistics', 'fraction')
ON CONFLICT (concept_id, prerequisite_id) DO NOTHING;

INSERT INTO knowledge_variants
  (concept_id, age_band_id, topic, glyph, doing, praise, check_question, answer, note)
VALUES
  (
    'count_objects',
    'toddler',
    '数三个苹果',
    '3',
    '点着数出三个苹果',
    '你能数出三个苹果',
    '再数一遍，还是三个吗？',
    '一样多。前后数得一样，就是数对了。',
    '用手指着一个一个数。'
  ),
  (
    'count_objects',
    'lower_primary',
    '20 以内加减',
    '+',
    '算出 8+5',
    '你能算出 8+5',
    '8+5 和 5+8 一样吗？',
    '一样，交换顺序结果不变。',
    '可以在纸上画小棍。'
  ),
  (
    'fraction',
    'upper_primary',
    '分数和面积',
    '½',
    '把一张纸分成四份，涂出其中的三分之一',
    '你能用面积说清一个分数',
    '同一张纸，四分之一和三分之一哪个大？',
    '三分之一大，因为分的份数少。',
    NULL
  ),
  (
    'fraction',
    'middle_school',
    '用方程表示关系',
    '=',
    '把一个生活问题写成方程',
    '你能把一句话写成方程',
    '等号两边各代表什么？',
    '一边是总量，一边是各部分之和。',
    NULL
  ),
  (
    'fraction',
    'high_school',
    '函数与数列',
    'ƒ',
    '写出一个数列的前四项，并说明它的规律',
    '你能用规律写出后面的项',
    '换一个起始项，规律还成立吗？',
    '先写通项，再代进去验证。',
    NULL
  ),
  (
    'statistics',
    'middle_school',
    '看一组数据的波动',
    '≈',
    '算出这组数的平均数和范围',
    '你能说出一组数的平均和范围',
    '平均数能代表每一个数吗？',
    '不能，它只说明总体位置。',
    NULL
  ),
  (
    'statistics',
    'high_school',
    '概率与抽样',
    'P',
    '说清一次抽样的范围和误差来源',
    '你能说清抽样可能哪里偏',
    '换一群人来抽，结果会一样吗？',
    '不一定，要看抽样范围和人数。',
    NULL
  ),
  (
    'statistics',
    'college',
    '微积分或统计入门',
    '∫',
    '选一门，读完一节并写出一个可复算的步骤',
    '你能写出可复算的一步',
    '别人照这一步能算出来吗？',
    '把数据和公式都写清楚。',
    NULL
  ),
  (
    'statistics',
    'beyond_school',
    '核对健康信息里的数字',
    '%',
    '找出这则信息里的基数和时间范围',
    '你能核对一个百分比背后的基数',
    '这个百分比是多少人中得出的？',
    '没有基数，百分比就不说明风险大小。',
    '看到的数字先问从哪来。'
  )
ON CONFLICT (concept_id, age_band_id) DO UPDATE SET
  topic = EXCLUDED.topic,
  glyph = EXCLUDED.glyph,
  doing = EXCLUDED.doing,
  praise = EXCLUDED.praise,
  check_question = EXCLUDED.check_question,
  answer = EXCLUDED.answer,
  note = EXCLUDED.note;
