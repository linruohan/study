-- 六类扩灌第二批(P4 内容扩展,按 doc/知识分类参考.md 的映射):
-- 思辨/表达/对抗/制作/群治/自知 各补 4 条概念,共 24 条。
-- 与 021 只覆盖幼儿/小学不同,本批每类 4 条分别落在
-- 12–14 / 15–17 / 18–20 / 离校后四档,depth 随年龄段加深(0 最浅)。
-- 挂 020 已建的子分类;知识点沿用 008 的展开规则(入门=topic/doing,
-- 熟练=check/answer,精通=praise),认知层级同 021 标注
-- (创造档由管理员按需追加,与 018 口径一致)。
-- 幂等:全部 ON CONFLICT。

-- ── 思辨之学(哲) ────────────────────────────────────────────────
-- 映射依据:知识分类参考.md 3.1/3.3/3.7(主张与证据、语义、模型条件、社会理论)
INSERT INTO knowledge_concepts (id, category_id, depth, sort_order) VALUES
  ('th_claim_evidence',  'th_philosophy',     0, 3),
  ('th_define_terms',    'th_linguistics',    1, 4),
  ('th_model_condition', 'th_logic_math',     2, 5),
  ('th_two_theories',    'th_social_theory',  3, 6)
ON CONFLICT (id) DO UPDATE SET
  category_id = EXCLUDED.category_id, depth = EXCLUDED.depth, sort_order = EXCLUDED.sort_order;

INSERT INTO knowledge_variants (concept_id, age_band_id, topic, doing, praise, check_question, answer, note) VALUES
  ('th_claim_evidence', 'middle_school',
   '主张和证据分得开',
   '读一段短文，把里面的主张各抄一行、支持它的证据各抄一行',
   '你能把主张和证据分开抄',
   '如果只有主张没有证据，这段话还能信吗？',
   '不能全信。它只是说法，还没给理由。',
   '「我认为」「因此」后面多是主张，「例如」「根据」后面多是证据。'),
  ('th_define_terms', 'high_school',
   '先定义关键词再讨论',
   '给一个争论题目里的关键词各写一句自己的定义，再开始论证',
   '你先定义关键词再论证',
   '双方吵的如果是同一个词的不同意思，怎么破？',
   '先把各自对这个词的定义摆出来，再比结论。',
   '定义写在一行里，太长说明还没想清。'),
  ('th_model_condition', 'college',
   '结论在什么条件下成立',
   '读一个模型或公式，列出它依赖的三条假设',
   '你能列出模型依赖的假设',
   '假设变了，结论还成立吗？',
   '不一定。要重新推，不能直接沿用。',
   '每个假设都要能回答「如果违反会怎样」。'),
  ('th_two_theories', 'beyond_school',
   '用两套说法解释同一件事',
   '选一件身边的事，分别用两套不同的理论各写一段解释',
   '你能用两套理论各解释一遍',
   '两套解释哪套更贴合事实？',
   '对着能核对的部分比，谁多解释了一件事实谁就更贴。',
   '解释完写下两套各自解释不了的地方。')
ON CONFLICT (concept_id, age_band_id) DO UPDATE SET
  topic = EXCLUDED.topic, doing = EXCLUDED.doing, praise = EXCLUDED.praise,
  check_question = EXCLUDED.check_question, answer = EXCLUDED.answer, note = EXCLUDED.note;

-- ── 表达之学(赋) ────────────────────────────────────────────────
-- 映射依据:3.5/3.12(叙事作品、修辞、视觉表达、创作媒介)
INSERT INTO knowledge_concepts (id, category_id, depth, sort_order) VALUES
  ('ex_story_turn',     'exp_literature',    0, 3),
  ('ex_say_differently','exp_rhetoric',      1, 4),
  ('ex_theme_series',   'exp_visual',        2, 5),
  ('ex_expressive_write','exp_lang_creation',3, 6)
ON CONFLICT (id) DO UPDATE SET
  category_id = EXCLUDED.category_id, depth = EXCLUDED.depth, sort_order = EXCLUDED.sort_order;

INSERT INTO knowledge_variants (concept_id, age_band_id, topic, doing, praise, check_question, answer, note) VALUES
  ('ex_story_turn', 'middle_school',
   '讲一个有转折的故事',
   '写一个三百字的小故事，中间必须有一次意外的转折',
   '你的故事有一次真正的转折',
   '转折之后人物做了什么不同的选择？',
   '人物的选择要跟着转折变，不然转折只是插曲。',
   '转折之前先埋一句伏笔，读起来才不突兀。'),
  ('ex_say_differently', 'high_school',
   '同一句话换个说法',
   '把一句生硬的通知改写成三种语气：正式、亲切、简短',
   '你能用三种语气改同一句话',
   '哪种说法最不会让人误会？',
   '信息排最前面的那种，语气不掩盖信息。',
   '改写不改意思：时间地点数字不能丢。'),
  ('ex_theme_series', 'college',
   '一组有主题的作品',
   '围绕一个主题做三件同系列的小作品，并各写两句创作说明',
   '你能做成有主题的系列',
   '三件作品靠什么连成一个系列？',
   '靠主题和一致的形式，不是靠数量。',
   '说明里写你放弃了哪些方案，比写成功更有用。'),
  ('ex_expressive_write', 'beyond_school',
   '把一天写成三行',
   '睡前用三行写下今天最强烈的一件事和自己的反应',
   '你连续写下三行的一天',
   '写下来的事和当时想的一样吗？',
   '常有出入。写下来会把情绪和事实分开。',
   '只给自己看，写事实和反应，不写评语。')
ON CONFLICT (concept_id, age_band_id) DO UPDATE SET
  topic = EXCLUDED.topic, doing = EXCLUDED.doing, praise = EXCLUDED.praise,
  check_question = EXCLUDED.check_question, answer = EXCLUDED.answer, note = EXCLUDED.note;

-- ── 对抗之学(战) ────────────────────────────────────────────────
-- 映射依据:3.3/五(谈判、竞技准备、网络安全、日常博弈)
INSERT INTO knowledge_concepts (id, category_id, depth, sort_order) VALUES
  ('st_trade_offer',   'st_diplomacy',   0, 3),
  ('st_match_prepare', 'st_competition', 1, 4),
  ('st_account_defense','st_cyber',      2, 5),
  ('st_daily_game',    'st_game_theory', 3, 6)
ON CONFLICT (id) DO UPDATE SET
  category_id = EXCLUDED.category_id, depth = EXCLUDED.depth, sort_order = EXCLUDED.sort_order;

INSERT INTO knowledge_variants (concept_id, age_band_id, topic, doing, praise, check_question, answer, note) VALUES
  ('st_trade_offer', 'middle_school',
   '谈成一次交换',
   '和同学谈一次条件交换：先想好自己能给的底线，再开口',
   '你带着底线去谈交换',
   '为什么先想底线再开口？',
   '开口后再想，容易被对方的话牵着走。',
   '谈成后把约定写下来，双方各留一份。'),
  ('st_match_prepare', 'high_school',
   '比赛前的准备',
   '为一场棋类或球类比赛写三行准备：自己的强项、对方的习惯、输了怎么办',
   '你能写出知己知彼的三行',
   '对方的习惯你怎么知道？',
   '看它以前怎么打，或者问打过的人。',
   '「输了怎么办」也要写，准备包含失败才算完整。'),
  ('st_account_defense', 'college',
   '账号攻防',
   '检查自己三个常用账号：密码是否重复、是否开了双重验证',
   '你能逐条检查自己的账号',
   '为什么密码不能到处用同一个？',
   '一个地方泄露，所有地方一起丢。',
   '先改最重复的那个，再补双重验证。'),
  ('st_daily_game', 'beyond_school',
   '猜对方下一步',
   '玩几轮猜拳或价格谈判游戏，记下对方出什么，再调整自己',
   '你能根据对方习惯调整自己',
   '一直固定出一样，会怎样？',
   '会被对方摸透，变成必输。',
   '让对方猜不透，比每次都赢一手更重要。')
ON CONFLICT (concept_id, age_band_id) DO UPDATE SET
  topic = EXCLUDED.topic, doing = EXCLUDED.doing, praise = EXCLUDED.praise,
  check_question = EXCLUDED.check_question, answer = EXCLUDED.answer, note = EXCLUDED.note;

-- ── 制作之学(匠) ────────────────────────────────────────────────
-- 映射依据:3.8(机械、计算机、土木营造、日常维护)
INSERT INTO knowledge_concepts (id, category_id, depth, sort_order) VALUES
  ('mk_bike_repair',   'mk_mech_energy', 0, 3),
  ('mk_sheet_tool',    'mk_computer',    1, 4),
  ('mk_draw_first',    'mk_civil_arch',  2, 5),
  ('mk_keep_running',  'mk_industrial',  3, 6)
ON CONFLICT (id) DO UPDATE SET
  category_id = EXCLUDED.category_id, depth = EXCLUDED.depth, sort_order = EXCLUDED.sort_order;

INSERT INTO knowledge_variants (concept_id, age_band_id, topic, doing, praise, check_question, answer, note) VALUES
  ('mk_bike_repair', 'middle_school',
   '保养一辆自行车',
   '给自行车补气、检查刹车、上油，每步做完试一下',
   '你能分步保养一辆车',
   '哪一步不试就直接骑最危险？',
   '刹车。不试就骑，下坡停不住。',
   '工具用完放回原处，下次才找得到。'),
  ('mk_sheet_tool', 'high_school',
   '用表格做一个小工具',
   '用电子表格做一张自动算合计和平均的记账表，家人能用',
   '你能做出别人能用的小工具',
   '怎么知道你的表算得对？',
   '手算一遍对答案，数字对得上才算。',
   '给别人用之前，先自己填一行假数据试。'),
  ('mk_draw_first', 'college',
   '动手前先画图',
   '做一个架子或布置一个房间前，先画尺寸图再下料',
   '你先画图量尺寸再动手',
   '画图省下的是什么？',
   '省下买错料、切错长度的返工。',
   '图上每个数都要写单位，没单位不能施工。'),
  ('mk_keep_running', 'beyond_school',
   '让东西多用一年',
   '给家里三样常用的东西各定一条保养规则并执行一个月',
   '你能坚持执行保养规则',
   '保养和坏了再修，哪个更省？',
   '多数情况下保养更省，修理费和停用期都是成本。',
   '规则写在东西旁边，看不见的规则等于没有。')
ON CONFLICT (concept_id, age_band_id) DO UPDATE SET
  topic = EXCLUDED.topic, doing = EXCLUDED.doing, praise = EXCLUDED.praise,
  check_question = EXCLUDED.check_question, answer = EXCLUDED.answer, note = EXCLUDED.note;

-- ── 群治之学(治) ────────────────────────────────────────────────
-- 映射依据:3.3/3.11(公共通知、预算、合同、组织行动)
INSERT INTO knowledge_concepts (id, category_id, depth, sort_order) VALUES
  ('gv_read_notice',  'gv_public_admin', 0, 3),
  ('gv_event_budget', 'gv_applied_econ', 1, 4),
  ('gv_read_contract','gv_law',          2, 5),
  ('gv_organize',     'gv_social_work',  3, 6)
ON CONFLICT (id) DO UPDATE SET
  category_id = EXCLUDED.category_id, depth = EXCLUDED.depth, sort_order = EXCLUDED.sort_order;

INSERT INTO knowledge_variants (concept_id, age_band_id, topic, doing, praise, check_question, answer, note) VALUES
  ('gv_read_notice', 'middle_school',
   '读懂一张通知',
   '从一张真实样式的通知里找出：时间、地点、要做什么、找谁',
   '你能从通知里找全四样信息',
   '通知里没写联系人的话，怎么补？',
   '去发布它的单位问，不要猜。',
   '读完按「什么时候去哪里做什么」复述一遍，才算读懂。'),
  ('gv_event_budget', 'high_school',
   '给活动做预算',
   '为一次班级活动列支出清单和收入来源，留出备用金额',
   '你能做出带余量的预算',
   '备用金留多少合适？',
   '留一成左右，东西涨价和临时加项都有地方吸收。',
   '预算超了要写超在哪一项，下次才不再超。'),
  ('gv_read_contract', 'college',
   '签之前读合同',
   '读一份示例合同，找出当事人、期限、费用、解除四栏并各抄一句',
   '你能找出合同的四个关键栏',
   '哪一栏最容易吃亏？',
   '解除栏。想退出时才发现条件苛刻。',
   '看不懂的栏目在签之前问明白，比签完再争容易。'),
  ('gv_organize', 'beyond_school',
   '组织一次集体行动',
   '约几个人做一件公共的事（大扫除、旧物回收），写清分工、时间和谁负责收尾',
   '你能把分工和收尾写清',
   '没有收尾负责人的活动会怎样？',
   '做一半散掉，下次没人再参加。',
   '做完把结果告诉每个参与者，第二次才有人来。')
ON CONFLICT (concept_id, age_band_id) DO UPDATE SET
  topic = EXCLUDED.topic, doing = EXCLUDED.doing, praise = EXCLUDED.praise,
  check_question = EXCLUDED.check_question, answer = EXCLUDED.answer, note = EXCLUDED.note;

-- ── 自知之学(我) ────────────────────────────────────────────────
-- 映射依据:3.4/3.10(学习目标、情绪调节、复盘、意义)
INSERT INTO knowledge_concepts (id, category_id, depth, sort_order) VALUES
  ('se_checkable_goal','se_learning',       0, 3),
  ('se_emotion_pause', 'se_therapy',        1, 4),
  ('se_review_done',   'se_self_management',2, 5),
  ('se_what_matters',  'se_philosophy',     3, 6)
ON CONFLICT (id) DO UPDATE SET
  category_id = EXCLUDED.category_id, depth = EXCLUDED.depth, sort_order = EXCLUDED.sort_order;

INSERT INTO knowledge_variants (concept_id, age_band_id, topic, doing, praise, check_question, answer, note) VALUES
  ('se_checkable_goal', 'middle_school',
   '定一个能检查的目标',
   '把「我要学好数学」改写成一句能检查的话：做什么、做多少、什么时候查',
   '你的目标能被检查',
   '「学好」为什么检查不了？',
   '没有边界，做到什么时候都算没做到。',
   '目标写小：「每天五道口算并自查」，比写大更有用。'),
  ('se_emotion_pause', 'high_school',
   '情绪来了先停一下',
   '生气或慌张时，先数三下并说出自己现在的情绪名字，再决定说什么',
   '你能先停下再开口',
   '停下来这三秒改变了什么？',
   '把「立刻反应」换成「选择过的反应」。',
   '停不住的时候先离开现场，不算认输。'),
  ('se_review_done', 'college',
   '复盘一次做完的事',
   '一件事结束后写三行：计划是什么、实际怎样、下次改一处什么',
   '你每次做完都留三行复盘',
   '为什么只改一处？',
   '改太多处等于没改，下次连哪处起作用都不知道。',
   '复盘写事实和动作，不写「下次努力」。'),
  ('se_what_matters', 'beyond_school',
   '我看重什么',
   '写下五件自己愿意花时间的非必需的事，按愿意程度排序',
   '你能排出自己的看重清单',
   '清单和时间记录对得上吗？',
   '对一周的时间记录核一次，不一致的以记录为准。',
   '清单每季重排一次，看重的东西会变。')
ON CONFLICT (concept_id, age_band_id) DO UPDATE SET
  topic = EXCLUDED.topic, doing = EXCLUDED.doing, praise = EXCLUDED.praise,
  check_question = EXCLUDED.check_question, answer = EXCLUDED.answer, note = EXCLUDED.note;

-- 知识点展开(与 008/021 规则一致)+ 认知层级标注。
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
  'th_claim_evidence','th_define_terms','th_model_condition','th_two_theories',
  'ex_story_turn','ex_say_differently','ex_theme_series','ex_expressive_write',
  'st_trade_offer','st_match_prepare','st_account_defense','st_daily_game',
  'mk_bike_repair','mk_sheet_tool','mk_draw_first','mk_keep_running',
  'gv_read_notice','gv_event_budget','gv_read_contract','gv_organize',
  'se_checkable_goal','se_emotion_pause','se_review_done','se_what_matters'
)
ON CONFLICT (concept_id, age_band_id, degree_id, position) DO UPDATE SET
  point = EXCLUDED.point, cognitive_level = EXCLUDED.cognitive_level;
