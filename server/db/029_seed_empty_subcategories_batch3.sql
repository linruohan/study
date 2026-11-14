-- 空子分类灌库第三批（P4 内容运营继续）:
-- 再灌 9 条，覆盖天地/表达/群治/生命/制作/自知/思辨，小学低年级到高中（不动蒙学档）。
-- 结构与知识点展开规则同 021–028（008 规则 + 认知层级），幂等。

INSERT INTO knowledge_concepts (id, category_id, depth, sort_order) VALUES
  ('co_room_map',        'co_geoinfo',    0, 1),
  ('co_traffic_feedback','co_systems',    0, 1),
  ('exp_code_flower',    'exp_creative_code', 0, 1),
  ('gv_forward_check',   'gv_media_gov',  0, 1),
  ('li_read_medbox',     'li_pharmacy',   0, 1),
  ('li_pet_vaccine',     'li_vet',        0, 1),
  ('mk_translate_trap',  'mk_lang_tech',  0, 1),
  ('se_slow_stretch',    'se_body_practice', 0, 1),
  ('th_word_rules',      'th_formal_lang', 0, 1)
ON CONFLICT (id) DO UPDATE SET
  category_id = EXCLUDED.category_id, depth = EXCLUDED.depth, sort_order = EXCLUDED.sort_order;

INSERT INTO knowledge_variants (concept_id, age_band_id, topic, doing, praise, check_question, answer, note) VALUES
  ('co_room_map', 'upper_primary',
   '给教室画一张平面图',
   '按固定步数测量教室，画一张带比例尺的平面图',
   '你画出了一张带比例尺的教室平面图',
   '为什么先量再画，不能看着画？',
   '看着画会走样；有测量和比例尺，别人才照着找到位置。',
   '先定比例（比如 1 步 = 1 格），再按门、窗、桌的顺序画。'),
  ('co_traffic_feedback', 'middle_school',
   '拥堵为什么会传染',
   '观察一条拥堵的道路，画出「慢→挤→更慢」的循环图',
   '你画出了一个会自我加强的循环',
   '一个环节变慢，为什么整条路都慢？',
   '一个环节变慢让后面的车更密，更密又更慢，这种环叫反馈环。',
   '找出环里「能掰开」的那一环，就是改系统的地方。'),
  ('exp_code_flower', 'upper_primary',
   '用循环画一朵花',
   '在图形化编程里用「重复 6 次：前进+旋转 60 度」画一朵花',
   '你用循环画出了六瓣花',
   '改成旋转 45 度会变成什么？',
   '旋转角度决定瓣数：360 ÷ 每次角度 = 花的对称数。',
   '先试 90 度再试 60 度，比较两次再改数字。'),
  ('gv_forward_check', 'middle_school',
   '转发前的三问',
   '给一条要转发的消息做三问检查：谁说的、哪里可查、有没有反例',
   '你转发的每条消息都过了三问检查',
   '为什么「大家都这么说」不算证据？',
   '同源的消息转发一百遍还是同一个来源；要找到最初的出处。',
   '查不到出处就写「未证实」，别帮它扩散。'),
  ('li_read_medbox', 'upper_primary',
   '药盒上的四个信息',
   '找一个药盒，读出药名、作用、用法用量和有效期',
   '你能读出药盒上的四个关键信息',
   '药剩下的还能留给下次生病吃吗？',
   '不能。药是对症开的，这次和上次不一定同一种病；吃错比不吃危险。',
   '任何药都先问家里大人；有效期过了直接扔。'),
  ('li_pet_vaccine', 'upper_primary',
   '宠物的疫苗日历',
   '给家里的宠物（或案例）列一张疫苗时间表，说清每针防什么',
   '你能列出宠物的疫苗时间表',
   '人为什么也要给宠物打疫苗？',
   '有些病能在动物和人之间传染（比如狂犬病），打疫苗保护它也保护人。',
   '日历贴在门上；漏了针先补种再出门遛。'),
  ('mk_translate_trap', 'middle_school',
   '翻译软件哪里会错',
   '把一句带双关的话丢给翻译软件，找出译错的地方并改正',
   '你能找出机器翻译译错的地方并改正',
   '为什么「意思意思」机器翻译不了？',
   '机器按词搭配规则翻，双关和俗语没有固定对应，要靠语境。',
   '回译一遍是自查的好办法：译过去再译回来，看意思丢没丢。'),
  ('se_slow_stretch', 'upper_primary',
   '拉伸为什么要慢慢拉',
   '做一次一分钟 slow 拉伸，对比弹压式拉伸的差别',
   '你对比了慢拉伸和弹压拉伸的差别',
   '弹得越狠是不是拉得越开？',
   '快速弹压会触发肌肉自我收紧保护；慢慢拉才拉得到深处。',
   '拉到「紧但不疼」停住数 30 秒；疼了立刻放松。'),
  ('th_word_rules', 'high_school',
   '用规则判断一句话合不合法',
   '自定三条造句规则，判断十个句子是否「合法」，写出判断过程',
   '你能按自定规则判断句子并写出过程',
   '规则里说「名词后接动词」，「他跑的快」合法吗？',
   '按规则不合法——「跑」后面接了「的」；规则判断只看形式，不看意思。',
   '形式判断是计算理论的起点：程序就是一套这样的规则。')
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
  'co_room_map','co_traffic_feedback','exp_code_flower','gv_forward_check',
  'li_read_medbox','li_pet_vaccine','mk_translate_trap',
  'se_slow_stretch','th_word_rules'
)
ON CONFLICT (concept_id, age_band_id, degree_id, position) DO UPDATE SET
  point = EXCLUDED.point, cognitive_level = EXCLUDED.cognitive_level;
