-- 知识库基础字典：年龄段、学习程度和九类分类。
-- 这些是枚举型数据，重复执行只更新描述，不会插重。

INSERT INTO knowledge_age_bands
  (id, label, short_label, how_to_learn, shows_subject_names, sort_order)
VALUES
  (
    'toddler',
    '3–5 岁',
    '幼儿',
    '点大图、听人说话。识字、数、情绪和动手混在同一条路线里。',
    false,
    1
  ),
  (
    'lower_primary',
    '6–8 岁',
    '小学低段',
    '从这一档起分科。读句子、口算、听说、观察和校园规则。',
    true,
    2
  ),
  (
    'upper_primary',
    '9–11 岁',
    '小学高段',
    '读懂一段、写出理由，做分数、面积和一次观察记录。',
    true,
    3
  ),
  (
    'middle_school',
    '12–14 岁',
    '初中',
    '学概念、找出处，用方程和实验说明关系。',
    true,
    4
  ),
  (
    'high_school',
    '15–17 岁',
    '高中',
    '追问原理与条件，用两则材料互相对照。',
    true,
    5
  ),
  (
    'college',
    '18–20 岁',
    '大学',
    '读文献、按方法做作业，写下可复算的步骤。',
    true,
    6
  ),
  (
    'beyond_school',
    '离开学校以后',
    '社会',
    '读通知、说明和可核对的常识，把学过的东西用在生活里。',
    true,
    7
  )
ON CONFLICT (id) DO UPDATE SET
  label = EXCLUDED.label,
  short_label = EXCLUDED.short_label,
  how_to_learn = EXCLUDED.how_to_learn,
  shows_subject_names = EXCLUDED.shows_subject_names,
  sort_order = EXCLUDED.sort_order;

INSERT INTO knowledge_degrees (id, label, sort_order)
VALUES
  ('beginner', '入门', 1),
  ('familiar', '熟悉', 2),
  ('advanced', '精通', 3)
ON CONFLICT (id) DO UPDATE SET
  label = EXCLUDED.label,
  sort_order = EXCLUDED.sort_order;

INSERT INTO knowledge_categories
  (id, name, question, ancient, modern, glyph, color, sort_order)
VALUES
  (
    'education',
    '教养之学',
    '人如何成为有文化、有价值根基的人',
    '六艺略',
    '哲学、历史学、语言学、教育学',
    '教',
    '#8C4A2F',
    1
  ),
  (
    'thought',
    '思辨之学',
    '人如何理解社会、秩序与观念',
    '诸子略',
    '政治学、经济学、法学、社会学、伦理学',
    '思',
    '#7A6A54',
    2
  ),
  (
    'expression',
    '表达之学',
    '人如何抒发情感、创造审美',
    '诗赋略',
    '文学、艺术学、音乐学、戏剧影视学',
    '诗',
    '#9C5B6E',
    3
  ),
  (
    'strategy',
    '对抗之学',
    '人如何应对冲突、竞争与组织博弈',
    '兵书略',
    '军事学、国际关系、博弈论',
    '弈',
    '#5B5E6E',
    4
  ),
  (
    'cosmos',
    '天地之学',
    '人如何认识与推算自然时空秩序',
    '数术略',
    '数学、天文学、物理学、化学、数据科学',
    '天',
    '#3E6F8C',
    5
  ),
  (
    'life',
    '生命之学',
    '人如何维护身体、健康与生命',
    '方技略',
    '医学、药学、公共卫生、体育学',
    '生',
    '#6F7A63',
    6
  ),
  (
    'making',
    '制作之学',
    '人如何改造世界、制造器物与系统',
    '散见于方技、兵书',
    '工学、农学、建筑学、材料科学',
    '工',
    '#4E7A78',
    7
  ),
  (
    'governance',
    '群治之学',
    '人如何组织大规模社会、分配资源与权力',
    '诸子、史部',
    '管理学、公共管理、制度法学',
    '群',
    '#837565',
    8
  ),
  (
    'self',
    '自知之学',
    '人如何认识自己——心智、行为与意义',
    '散见于诸子、方技',
    '心理学、认知科学、人类学',
    '己',
    '#6A5A82',
    9
  )
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  question = EXCLUDED.question,
  ancient = EXCLUDED.ancient,
  modern = EXCLUDED.modern,
  glyph = EXCLUDED.glyph,
  color = EXCLUDED.color,
  sort_order = EXCLUDED.sort_order;
