-- 空子分类灌库第一批（P4 内容运营继续）:
-- 天地/教养/表达/群治/生命/制作/自知七类各取最基础的一到两个空子分类，
-- 共 9 条概念，年龄段从小学低年级铺到高中（不动蒙学档，避免影响既有入口排序）。
-- 结构与知识点展开规则同 021–023（008 规则 + 认知层级），幂等。

INSERT INTO knowledge_concepts (id, category_id, depth, sort_order) VALUES
  ('co_sink_float',      'co_physics',      0, 1),
  ('co_acid_base',       'co_chemistry',    0, 1),
  ('classic_passdown',   'edu_classics',    0, 1),
  ('edu_teach_back',     'edu_education',   0, 1),
  ('exp_stage_conflict', 'exp_drama_film',  0, 1),
  ('gv_class_rules',     'gv_politics',     0, 1),
  ('li_checkup_report',  'li_clinical',     0, 1),
  ('mk_torch_circuit',   'mk_electronic',   0, 1),
  ('se_memory_curve',    'se_cogsci',       0, 1)
ON CONFLICT (id) DO UPDATE SET
  category_id = EXCLUDED.category_id, depth = EXCLUDED.depth, sort_order = EXCLUDED.sort_order;

INSERT INTO knowledge_variants (concept_id, age_band_id, topic, doing, praise, check_question, answer, note) VALUES
  ('co_sink_float', 'lower_primary',
   '什么沉什么浮',
   '把五样东西放进水里，先猜再试，记下谁沉谁浮',
   '你先猜了再试，还记下了结果',
   '猜错了怎么办？',
   '把猜的和试的都写下来，猜错的地方就是新发现。',
   '重的容易沉，但形状也能让大东西浮起来，比如船。'),
  ('co_acid_base', 'upper_primary',
   '厨房里的酸和碱',
   '用紫甘蓝水试三种厨房液体，分出酸的和碱的',
   '你能用颜色变化分出酸和碱',
   '为什么颜色会变？',
   '紫甘蓝水遇到酸和碱会变不同的颜色，这是它的特性。',
   '试之前先猜再验证；闻气味不能代替测试。'),
  ('classic_passdown', 'high_school',
   '一部典籍怎么传到今天',
   '挑一部古籍，查它的版本源流，画出传抄或刊印的脉络',
   '你能查清一部书从古到今怎么传下来',
   '为什么同一个书名会有不同的「版本」？',
   '手抄会抄错，重刻会改动，年代越早的版本往往越接近原貌。',
   '每个结论都要写出处；查不到的标「存疑」，别编。'),
  ('edu_teach_back', 'middle_school',
   '教别人是最深的学习',
   '把最近学会的一件事讲给一个人听，讲到对方能复述',
   '你能把学到的东西讲明白到别人能复述',
   '讲不清楚的地方说明什么？',
   '卡壳的地方就是你还没真懂的地方，回去补那一段。',
   '先自己列三句话提纲，讲完请对方复述一遍。'),
  ('exp_stage_conflict', 'middle_school',
   '看懂一场戏的冲突',
   '看一幕短剧或一段影片，说出谁想要什么、什么在拦着',
   '你能说出一幕戏里的人物想要什么、什么在拦着',
   '没有冲突的戏还能看下去吗？',
   '人物想要什么（目标）和什么拦着（阻碍），冲突就这两样。',
   '用一句话说清：谁+想要什么+但是什么。'),
  ('gv_class_rules', 'upper_primary',
   '班规是怎么长出来的',
   '给班级拟一条新规矩，说清它解决什么问题、谁同意谁反对',
   '你能拟一条规矩并说清它的理由',
   '规矩为什么不能只有一条「听老师的」？',
   '规矩要说清：管什么、例外怎么办、谁来判断，不然执行不了。',
   '好规矩是能执行的；写完问一句「违反了怎么办」。'),
  ('li_checkup_report', 'middle_school',
   '看懂一次体检报告',
   '拿一份体检报告（可用样例），找出不在参考范围内的项目并查含义',
   '你能找出报告里的异常项并查清含义',
   '参考范围一样，是不是所有人标准都一样？',
   '参考范围因年龄性别而不同；轻微异常不等于生病，要结合医生判断。',
   '报告只反映抽血那一刻；异常项要复查才算数。'),
  ('mk_torch_circuit', 'lower_primary',
   '点亮一个手电筒电路',
   '用电池、导线和小灯泡搭一个能亮的回路，画下来',
   '你搭出了一个能亮的回路并画了下来',
   '灯不亮的时候先检查什么？',
   '电流要走一圈：电池正极→灯泡→负极，中间断开就不亮。',
   '只能用干电池，不要碰插座；亮不了先查两头接没接紧。'),
  ('se_memory_curve', 'upper_primary',
   '忘得快是因为没复习',
   '用一组词语测自己隔一天还记得几个，画出遗忘的形状',
   '你能测出自己的遗忘曲线并画出形状',
   '隔一天再背，为什么比当天背省力？',
   '快忘的是没理解的；理解过的东西忘得慢，复习要放在快忘之前。',
   '测两次（当天和隔一天），用同一个词表才可比。')
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
  'co_sink_float','co_acid_base','classic_passdown','edu_teach_back',
  'exp_stage_conflict','gv_class_rules','li_checkup_report',
  'mk_torch_circuit','se_memory_curve'
)
ON CONFLICT (concept_id, age_band_id, degree_id, position) DO UPDATE SET
  point = EXCLUDED.point, cognitive_level = EXCLUDED.cognitive_level;
