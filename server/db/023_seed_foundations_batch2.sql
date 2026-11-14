-- 原有三类(教养/天地/生命)的知识加深(P4 内容运营第二批):
-- 教育学/天地/生命各补 3 条概念,挂 020 子分类,年龄段往初中/高中延伸。
-- 结构与知识点展开规则同 021,幂等。

INSERT INTO knowledge_concepts (id, category_id, depth, sort_order) VALUES
  ('his_family_story', 'edu_history',      0, 1),
  ('festival_origins', 'edu_heritage',     1, 2),
  ('classic_letter',   'edu_lang_classic', 2, 3),
  ('math_ratio',       'math',             0, 1),
  ('co_moon_phase',    'co_astro',         1, 2),
  ('co_weather_log',   'co_earth',         2, 3),
  ('li_handwash',      'li_public_health', 0, 1),
  ('li_food_label',    'li_nutrition',     1, 2),
  ('li_small_cut',     'li_basic_medicine',2, 3)
ON CONFLICT (id) DO UPDATE SET
  category_id = EXCLUDED.category_id, depth = EXCLUDED.depth, sort_order = EXCLUDED.sort_order;

INSERT INTO knowledge_variants (concept_id, age_band_id, topic, doing, praise, check_question, answer, note) VALUES
  ('his_family_story', 'middle_school',
   '记下一位长辈的故事',
   '采访一位长辈，写下他亲历的一件事',
   '你能记下一位长辈的亲历故事',
   '这件事发生在哪一年？怎么核对的？',
   '用大事年份对一遍，比如上学、搬家、工作。',
   '口述史要写「谁在什么时候说的」。'),
  ('festival_origins', 'upper_primary',
   '节日的来历',
   '查一个节日的来历，再写下自家过法有什么不同',
   '你能查到节日来历并对照自家过法',
   '书上的过法和家里的过法一样吗？',
   '常有不同。不同处就是家里的传统。',
   '来历要写出处，家里的过法要问长辈。'),
  ('classic_letter', 'high_school',
   '读一封古人的书信',
   '读一封古文书信，写出他要办的事和当时的心情',
   '你能读出书信里的事与情',
   '哪一句是正事，哪一句是问候？',
   '正事常在中段，首尾多是问候与客套。',
   '不确定的字先查，别猜。'),
  ('math_ratio', 'middle_school',
   '用比例解决生活问题',
   '用比例算一个生活问题，比如调饮料或看地图',
   '你能用比例算出生活问题的答案',
   '比例里什么变了，什么没变？',
   '变的是数量，不变的是两者之间的倍数。',
   '算完代回原条件检查一遍。'),
  ('co_moon_phase', 'lower_primary',
   '看月亮的变化',
   '连续两周在同一个时间看月亮并画下来',
   '你能记录两周的月亮变化',
   '月亮的形状每天都一样吗？',
   '不一样。它从弯到圆再变弯。',
   '阴天看不到，就记「阴」，别编。'),
  ('co_weather_log', 'upper_primary',
   '一周天气的规律',
   '记录一周天气，找出一条规律',
   '你能从记录里找出一条天气规律',
   '你的规律是猜的，还是从记录里看出来的？',
   '要写清是几天里看到的，不能只凭一天。',
   '记录要写日期和来源，规律才可信。'),
  ('li_handwash', 'lower_primary',
   '洗手的七步',
   '按七步洗手法洗手，说出为什么要这么做',
   '你能按七步洗手并说出原因',
   '随便冲一下和七步洗手差别在哪？',
   '指缝、指尖和手腕最容易留脏东西。',
   '唱完一首生日歌的时间差不多够。'),
  ('li_food_label', 'upper_primary',
   '看懂营养成分表',
   '读一个包装食品的营养成分表，说出它的高与低',
   '你能读出食品成分表的高低',
   '每 100 克含糖多少算高？',
   '对照NRV百分比，超过三成就不算低。',
   '比较要看「每100克」，不能比「每包」。'),
  ('li_small_cut', 'middle_school',
   '小伤口的正确处理',
   '说出小伤口处理的三步，并演示第一步',
   '你能说出小伤口处理的三步',
   '伤口处理的第一步是什么？',
   '先用清水冲干净，再止血，最后保护。',
   '又深又流血不止的伤口要找大人送医。')
ON CONFLICT (concept_id, age_band_id) DO UPDATE SET
  topic = EXCLUDED.topic, doing = EXCLUDED.doing, praise = EXCLUDED.praise,
  check_question = EXCLUDED.check_question, answer = EXCLUDED.answer, note = EXCLUDED.note;

-- 知识点展开(008 规则)+ 认知层级:记忆/理解/应用/分析/评价。
INSERT INTO knowledge_variant_points
  (concept_id, age_band_id, degree_id, position, point, cognitive_level)
SELECT v.concept_id, v.age_band_id, p.degree_id, p.position, p.point, p.level
FROM knowledge_variants v
CROSS JOIN LATERAL (
  VALUES
    ('beginner', 1, v.topic,  'remember'),
    ('beginner', 2, v.doing,  'understand'),
    ('familiar', 1, v.check_question, 'apply'),
    ('familiar', 2, v.answer, 'analyze'),
    ('advanced', 1, v.praise, 'evaluate')
) AS p(degree_id, position, point, level)
WHERE v.concept_id IN (
  'his_family_story','festival_origins','classic_letter',
  'math_ratio','co_moon_phase','co_weather_log',
  'li_handwash','li_food_label','li_small_cut'
)
ON CONFLICT (concept_id, age_band_id, degree_id, position) DO UPDATE SET
  point = EXCLUDED.point, cognitive_level = EXCLUDED.cognitive_level;
