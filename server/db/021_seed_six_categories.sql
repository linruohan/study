-- 六类空分类的起步知识(P4-1):思辨/表达/对抗/制作/群治/自知,
-- 每类 2 条概念,挂在 020 已建的子分类下,年龄段取蒙学或小学低/高段。
-- 知识点沿用 008 的展开规则(入门=topic/doing,熟练=check/answer,精通=praise),
-- 并显式标注认知层级(记忆/理解/应用/分析/评价/创新)。
-- 幂等:全部 ON CONFLICT。

-- 思辨之学(哲)→ th_* 子分类
INSERT INTO knowledge_concepts (id, category_id, depth, sort_order) VALUES
  ('th_rules_family', 'th_ethics_aesthetics', 0, 1),
  ('th_two_sides',    'th_philosophy',        1, 2)
ON CONFLICT (id) DO UPDATE SET
  category_id = EXCLUDED.category_id, depth = EXCLUDED.depth, sort_order = EXCLUDED.sort_order;

INSERT INTO knowledge_variants (concept_id, age_band_id, topic, doing, praise, check_question, answer, note) VALUES
  ('th_rules_family', 'lower_primary',
   '家里的规则为什么存在',
   '说出一条家里的规则，并说它保护了谁',
   '你能说出规则在保护谁',
   '如果没有这条规则，会发生什么？',
   '可能有人的安全或休息被影响。',
   '规则不是限制你，是让每个人都过得去。'),
  ('th_two_sides', 'upper_primary',
   '一件事的两面',
   '就一件班里的争议各写一句支持和一句担心',
   '你能同时写出支持和担心',
   '只听一方的说法够吗？',
   '不够。另一方的理由还没听。',
   '先各写一句，再交换角色读一遍。')
ON CONFLICT (concept_id, age_band_id) DO UPDATE SET
  topic = EXCLUDED.topic, doing = EXCLUDED.doing, praise = EXCLUDED.praise,
  check_question = EXCLUDED.check_question, answer = EXCLUDED.answer, note = EXCLUDED.note;

-- 表达之学(赋)→ ex_* 子分类
INSERT INTO knowledge_concepts (id, category_id, depth, sort_order) VALUES
  ('ex_sing_folk',   'exp_music',    0, 1),
  ('ex_draw_feeling','exp_visual',   1, 2)
ON CONFLICT (id) DO UPDATE SET
  category_id = EXCLUDED.category_id, depth = EXCLUDED.depth, sort_order = EXCLUDED.sort_order;

INSERT INTO knowledge_variants (concept_id, age_band_id, topic, doing, praise, check_question, answer, note) VALUES
  ('ex_sing_folk', 'toddler',
   '唱一段童谣',
   '跟大人唱一段熟悉的童谣',
   '你能跟着唱一段童谣',
   '哪一句你最喜欢？',
   '说得出那句就行，不用解释。',
   '唱错也没关系，跟着节奏就好。'),
  ('ex_draw_feeling', 'lower_primary',
   '画出一种心情',
   '用颜色和形状画出今天的心情',
   '你能画出今天的心情',
   '别人看得出你画的是什么心情吗？',
   '能说出大概就行，颜色没有标准答案。',
   '画完说一句你为什么用这个颜色。')
ON CONFLICT (concept_id, age_band_id) DO UPDATE SET
  topic = EXCLUDED.topic, doing = EXCLUDED.doing, praise = EXCLUDED.praise,
  check_question = EXCLUDED.check_question, answer = EXCLUDED.answer, note = EXCLUDED.note;

-- 对抗之学(战)→ st_* 子分类
INSERT INTO knowledge_concepts (id, category_id, depth, sort_order) VALUES
  ('st_take_turns', 'st_game_theory', 0, 1),
  ('st_safe_route', 'st_security',    1, 2)
ON CONFLICT (id) DO UPDATE SET
  category_id = EXCLUDED.category_id, depth = EXCLUDED.depth, sort_order = EXCLUDED.sort_order;

INSERT INTO knowledge_variants (concept_id, age_band_id, topic, doing, praise, check_question, answer, note) VALUES
  ('st_take_turns', 'toddler',
   '轮流玩',
   '在游戏里等对方走完再走',
   '你能等对方走完再走',
   '为什么不能两个人同时走？',
   '同时走就乱套了，谁都玩不成。',
   '等待也是游戏的一部分。'),
  ('st_safe_route', 'upper_primary',
   '上学路上的安全选择',
   '标出上学路上有风险的地点和更稳的走法',
   '你能标出风险点和更稳的走法',
   '哪一段最容易出事？为什么？',
   '路口、视线被挡的地方最容易出事。',
   '说不准的地方，走人多的那一条。')
ON CONFLICT (concept_id, age_band_id) DO UPDATE SET
  topic = EXCLUDED.topic, doing = EXCLUDED.doing, praise = EXCLUDED.praise,
  check_question = EXCLUDED.check_question, answer = EXCLUDED.answer, note = EXCLUDED.note;

-- 制作之学(匠)→ mk_* 子分类
INSERT INTO knowledge_concepts (id, category_id, depth, sort_order) VALUES
  ('mk_fold_paper', 'mk_craft',      0, 1),
  ('mk_fix_wobble', 'mk_mech_energy', 1, 2)
ON CONFLICT (id) DO UPDATE SET
  category_id = EXCLUDED.category_id, depth = EXCLUDED.depth, sort_order = EXCLUDED.sort_order;

INSERT INTO knowledge_variants (concept_id, age_band_id, topic, doing, praise, check_question, answer, note) VALUES
  ('mk_fold_paper', 'lower_primary',
   '折一件纸工',
   '照步骤折出一件纸工作品',
   '你能照步骤折完一件作品',
   '哪一步最容易折歪？',
   '对齐的那一步。没对齐后面会越来越歪。',
   '歪了就拆开重折，不用换纸。'),
  ('mk_fix_wobble', 'upper_primary',
   '修稳一把晃动的椅子',
   '找出椅子晃的原因，选一个办法修稳它',
   '你能找出晃动的原因并修稳它',
   '是腿松了，还是地面不平？',
   '先在平地上试，才能分清是腿还是地面。',
   '修完要再晃一晃来验证。')
ON CONFLICT (concept_id, age_band_id) DO UPDATE SET
  topic = EXCLUDED.topic, doing = EXCLUDED.doing, praise = EXCLUDED.praise,
  check_question = EXCLUDED.check_question, answer = EXCLUDED.answer, note = EXCLUDED.note;

-- 群治之学(治)→ gv_* 子分类
INSERT INTO knowledge_concepts (id, category_id, depth, sort_order) VALUES
  ('gv_class_duty',  'gv_management',   0, 1),
  ('gv_shared_books','gv_public_admin', 1, 2)
ON CONFLICT (id) DO UPDATE SET
  category_id = EXCLUDED.category_id, depth = EXCLUDED.depth, sort_order = EXCLUDED.sort_order;

INSERT INTO knowledge_variants (concept_id, age_band_id, topic, doing, praise, check_question, answer, note) VALUES
  ('gv_class_duty', 'lower_primary',
   '值日怎么分工',
   '把值日任务分给每个人，并说清谁做什么',
   '你能把任务分清并说清',
   '有人请假了，他的任务谁来做？',
   '要提前定一个替补的办法。',
   '分工写在大家都看得到的地方。'),
  ('gv_shared_books', 'upper_primary',
   '共用图书的管理',
   '给班级图书角定三条使用规则',
   '你能定出三条大家同意的规则',
   '规则要解决什么问题？',
   '借了不还、找不到、弄坏了怎么办。',
   '规则要有"做不到怎么办"才算数。')
ON CONFLICT (concept_id, age_band_id) DO UPDATE SET
  topic = EXCLUDED.topic, doing = EXCLUDED.doing, praise = EXCLUDED.praise,
  check_question = EXCLUDED.check_question, answer = EXCLUDED.answer, note = EXCLUDED.note;

-- 自知之学(我)→ se_* 子分类
INSERT INTO knowledge_concepts (id, category_id, depth, sort_order) VALUES
  ('se_name_feeling', 'se_psychology', 0, 1),
  ('se_my_strengths', 'se_identity',   1, 2)
ON CONFLICT (id) DO UPDATE SET
  category_id = EXCLUDED.category_id, depth = EXCLUDED.depth, sort_order = EXCLUDED.sort_order;

INSERT INTO knowledge_variants (concept_id, age_band_id, topic, doing, praise, check_question, answer, note) VALUES
  ('se_name_feeling', 'toddler',
   '叫出心情的名字',
   '用「高兴」「难过」「生气」说出现在的心情',
   '你能说出现在的心情',
   '刚才的心情和现在一样吗？',
   '心情会变，说得出就是本事。',
   '说不出来时，可以指表情卡片。'),
  ('se_my_strengths', 'upper_primary',
   '我的长处清单',
   '写下三件你做得比别人好的小事',
   '你能写下三件自己的长处',
   '这三件事别人也认可吗？',
   '问一问身边的人，核对是不是事实。',
   '写事实，不写「我很聪明」这种空话。')
ON CONFLICT (concept_id, age_band_id) DO UPDATE SET
  topic = EXCLUDED.topic, doing = EXCLUDED.doing, praise = EXCLUDED.praise,
  check_question = EXCLUDED.check_question, answer = EXCLUDED.answer, note = EXCLUDED.note;

-- 知识点展开(与 008 规则一致)+ 认知层级标注。
-- 顺序:入门1=记忆(topic),入门2=理解(doing),熟练1=应用(check),熟练2=分析(answer),精通1=评价(praise)。
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
  'th_rules_family','th_two_sides','ex_sing_folk','ex_draw_feeling',
  'st_take_turns','st_safe_route','mk_fold_paper','mk_fix_wobble',
  'gv_class_duty','gv_shared_books','se_name_feeling','se_my_strengths'
)
ON CONFLICT (concept_id, age_band_id, degree_id, position) DO UPDATE SET
  point = EXCLUDED.point, cognitive_level = EXCLUDED.cognitive_level;
