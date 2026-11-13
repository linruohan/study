-- 生活与安全领域：覆盖「衣食住行」里的安全常识，从远离火到合同条款。
-- 数据来源：app/lib/knowledge/catalog/life.dart，两边改动要同步。

INSERT INTO knowledge_domains
  (id, name, glyph, color, category_id, sort_order)
VALUES
  ('life', '生活与安全', '安', '#6F7A63', 'life', 3)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  glyph = EXCLUDED.glyph,
  color = EXCLUDED.color,
  category_id = EXCLUDED.category_id,
  sort_order = EXCLUDED.sort_order;

INSERT INTO knowledge_concepts (id, domain_id, depth, sort_order)
VALUES
  ('fire_safety', 'life', 0, 1),
  ('electric_safety', 'life', 1, 2),
  ('food_expiry', 'life', 2, 3),
  ('contract', 'life', 3, 4)
ON CONFLICT (id) DO UPDATE SET
  domain_id = EXCLUDED.domain_id,
  depth = EXCLUDED.depth,
  sort_order = EXCLUDED.sort_order;

INSERT INTO knowledge_concept_prerequisites (concept_id, prerequisite_id)
VALUES
  ('electric_safety', 'fire_safety')
ON CONFLICT (concept_id, prerequisite_id) DO NOTHING;

INSERT INTO knowledge_variants
  (concept_id, age_band_id, topic, glyph, doing, praise, check_question, answer, note)
VALUES
  (
    'fire_safety',
    'toddler',
    '看见火要远离',
    '火',
    '指出哪里有火，并去找大人',
    '你能看见火就找大人',
    '看见火，先做什么？',
    '离远一点，再叫大人。',
    '灶台、打火机、蜡烛都算火。'
  ),
  (
    'fire_safety',
    'lower_primary',
    '火需要空气',
    '火',
    '说清盖上盖子为什么火会变小',
    '你能说出火需要空气',
    '把杯子扣在蜡烛上，会怎样？',
    '空气用完了，火就灭。',
    '这一步由大人操作。'
  ),
  (
    'fire_safety',
    'middle_school',
    '燃烧三要素',
    '火',
    '写出可燃物、助燃物和着火点',
    '你能说出燃烧的三个条件',
    '少一个条件，还能烧起来吗？',
    '三个同时有，才会持续燃烧。',
    NULL
  ),
  (
    'fire_safety',
    'college',
    '火灾动力学与逃生限制',
    '火',
    '读一份消防说明，写出两条逃生限制',
    '你能说出火场里不能做的事',
    '为什么不能乘电梯？',
    '断电和烟气会让电梯停住。',
    NULL
  ),
  (
    'electric_safety',
    'lower_primary',
    '不碰插座',
    '电',
    '指出家里不能用手碰的两处',
    '你能指出不能碰的插座',
    '手湿的时候能碰开关吗？',
    '不能，先擦干，再叫大人。',
    NULL
  ),
  (
    'electric_safety',
    'upper_primary',
    '湿手不碰开关',
    '电',
    '说出一个湿手用电的危险',
    '你能说出湿手用电的危险',
    '电器进水后第一步做什么？',
    '先断电，再由大人处理。',
    NULL
  ),
  (
    'electric_safety',
    'middle_school',
    '家庭电路和保险',
    '电',
    '说清保险丝或断路器在保护什么',
    '你能说出保险装置在保护什么',
    '电流过大时，谁先断开？',
    '保险丝或断路器先断开。',
    NULL
  ),
  (
    'electric_safety',
    'high_school',
    '功率与安全余量',
    '电',
    '算出一个插排还能接多少瓦',
    '你能算出插排的安全余量',
    '标称功率是上限，还是起点？',
    '是上限，不能贴着上限长期用。',
    NULL
  ),
  (
    'electric_safety',
    'beyond_school',
    '跳闸以后先做什么',
    '电',
    '写出跳闸后的检查顺序',
    '你能写出跳闸后的检查顺序',
    '合闸之前要先做什么？',
    '先拔掉大功率电器，再查线路。',
    NULL
  ),
  (
    'food_expiry',
    'lower_primary',
    '看保质期',
    '食',
    '找出一盒牛奶的保质日期',
    '你能找到保质期',
    '今天在保质期内吗？',
    '把今天和日期比一比。',
    NULL
  ),
  (
    'food_expiry',
    'upper_primary',
    '看清保存条件',
    '食',
    '说出这盒东西要不要冷藏',
    '你能看懂保存条件',
    '放常温会怎样？',
    '可能提前坏掉。',
    NULL
  ),
  (
    'food_expiry',
    'beyond_school',
    '判断还能不能吃',
    '食',
    '按日期、外观和保存条件写下判断',
    '你能按三条线索判断食物',
    '只看日期够吗？',
    '不够，还要看保存条件和是否变质。',
    NULL
  ),
  (
    'contract',
    'college',
    '合同里先看哪几条',
    '约',
    '在一份合同里标出期限、金额和解除条件',
    '你能找出合同的三处关键条款',
    '哪一条说了怎么退出？',
    '解除或终止的那一条。',
    NULL
  ),
  (
    'contract',
    'beyond_school',
    '签字前的三个问题',
    '约',
    '写下：和谁签、做什么、怎么退出',
    '你能在签字前问清三件事',
    '口头承诺和纸上写的不同，以哪个为准？',
    '以书面条款为准，不确定就先问。',
    '这不是法律意见。'
  )
ON CONFLICT (concept_id, age_band_id) DO UPDATE SET
  topic = EXCLUDED.topic,
  glyph = EXCLUDED.glyph,
  doing = EXCLUDED.doing,
  praise = EXCLUDED.praise,
  check_question = EXCLUDED.check_question,
  answer = EXCLUDED.answer,
  note = EXCLUDED.note;
