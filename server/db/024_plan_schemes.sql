-- 学习计划方案：蒙学、小学一年级……大一等为系统内置默认方案（is_builtin=true），
-- 用户也可以创建自己的方案（owner_user_id 指向创建者）。
-- 方案按「维度（领域）→ 知识内容 → 学习程度」组织，与 doc/分阶段学习方案.md 对齐；
-- 维度条目除文字内容外，可关联 knowledge_concepts（能挂上的挂，挂不上的置空）。
-- idempotent：内置方案维度/条目先删后插（内置方案不可被用户修改，无自建数据混入），
-- 方案行本身用 ON CONFLICT (id) DO UPDATE。

CREATE TABLE IF NOT EXISTS plan_schemes (
  id text PRIMARY KEY,
  name text NOT NULL,
  -- mengxue / primary / junior / senior / college / graduate / master
  stage text NOT NULL,
  stage_sort integer NOT NULL,
  sort_order integer NOT NULL,
  description text NOT NULL DEFAULT '',
  is_builtin boolean NOT NULL DEFAULT false,
  owner_user_id uuid REFERENCES users (id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE plan_schemes IS '学习计划方案：内置默认方案 + 用户自建方案';

CREATE TABLE IF NOT EXISTS plan_scheme_dimensions (
  id text PRIMARY KEY,
  scheme_id text NOT NULL REFERENCES plan_schemes (id) ON DELETE CASCADE,
  name text NOT NULL,
  sort_order integer NOT NULL
);

COMMENT ON TABLE plan_scheme_dimensions IS '方案维度（领域）：如「语言与识字」「语文」';

CREATE TABLE IF NOT EXISTS plan_scheme_items (
  id text PRIMARY KEY,
  dimension_id text NOT NULL REFERENCES plan_scheme_dimensions (id) ON DELETE CASCADE,
  content text NOT NULL,
  expected_level text NOT NULL DEFAULT '',
  concept_id text REFERENCES knowledge_concepts (id) ON DELETE SET NULL,
  sort_order integer NOT NULL
);

COMMENT ON TABLE plan_scheme_items IS '方案维度条目：知识内容 + 学习程度，可选关联知识概念';

CREATE INDEX IF NOT EXISTS plan_schemes_stage_idx
  ON plan_schemes (stage_sort, sort_order);
CREATE INDEX IF NOT EXISTS plan_scheme_dimensions_scheme_idx
  ON plan_scheme_dimensions (scheme_id, sort_order);
CREATE INDEX IF NOT EXISTS plan_scheme_items_dimension_idx
  ON plan_scheme_items (dimension_id, sort_order);

-- ── 蒙学 ──────────────────────────────────────────────────────────────
INSERT INTO plan_schemes (id, name, stage, stage_sort, sort_order, description, is_builtin) VALUES
  ('scheme_mengxue', '蒙学', 'mengxue', 0, 1,
   '学前启蒙阶段（约 3–6 岁）：建立安全感与学习兴趣，发展语言、感知、动作、情绪与社会性基础。', true)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, stage = EXCLUDED.stage, stage_sort = EXCLUDED.stage_sort,
  sort_order = EXCLUDED.sort_order, description = EXCLUDED.description, is_builtin = true;

DELETE FROM plan_scheme_dimensions WHERE scheme_id = 'scheme_mengxue';

INSERT INTO plan_scheme_dimensions (id, scheme_id, name, sort_order) VALUES
  ('schm_mengxue_1', 'scheme_mengxue', '语言与识字', 1),
  ('schm_mengxue_2', 'scheme_mengxue', '数学启蒙',   2),
  ('schm_mengxue_3', 'scheme_mengxue', '科学与探究', 3),
  ('schm_mengxue_4', 'scheme_mengxue', '艺术与审美', 4),
  ('schm_mengxue_5', 'scheme_mengxue', '健康与运动', 5),
  ('schm_mengxue_6', 'scheme_mengxue', '社会与情绪', 6);

INSERT INTO plan_scheme_items (id, dimension_id, content, expected_level, concept_id, sort_order) VALUES
  ('schi_mengxue_1_1', 'schm_mengxue_1', '听故事、儿歌、常用词汇；看图认字；简单口语表达',
   '能听懂简单指令与故事大意；愿意表达；认识少量常见字词（不强求书写）', 'zi_ri', 1),
  ('schi_mengxue_2_1', 'schm_mengxue_2', '数数、比大小、认形状、简单分类与对应',
   '能点数常见物品；辨别多少、长短、大小；认识基本图形', 'count_objects', 1),
  ('schi_mengxue_3_1', 'schm_mengxue_3', '观察动植物、天气、水与影子等生活现象',
   '对周围事物有好奇心；能用简单语言描述观察结果', 'co_weather_log', 1),
  ('schi_mengxue_4_1', 'schm_mengxue_4', '涂鸦、手工、音乐律动、欣赏图画',
   '愿意参与创作与表现；能跟随节奏做简单动作', 'ex_sing_folk', 1),
  ('schi_mengxue_5_1', 'schm_mengxue_5', '基本动作、卫生习惯、作息常规',
   '能完成走跑跳等基础动作；养成洗手、整理等习惯', 'li_handwash', 1),
  ('schi_mengxue_6_1', 'schm_mengxue_6', '规则意识、分享合作、情绪表达',
   '能在引导下等待与轮流；初步识别并表达基本情绪', 'se_name_feeling', 1);

-- ── 小学（一年级至六年级） ────────────────────────────────────────────
INSERT INTO plan_schemes (id, name, stage, stage_sort, sort_order, description, is_builtin) VALUES
  ('scheme_p1', '小学一年级', 'primary', 1, 1, '掌握基础读写算能力，形成学习习惯与规则意识。', true),
  ('scheme_p2', '小学二年级', 'primary', 1, 2, '读写算更熟练，开始独立完成学习与生活任务。', true),
  ('scheme_p3', '小学三年级', 'primary', 1, 3, '段落阅读与习作起步，形成初步证据意识。', true),
  ('scheme_p4', '小学四年级', 'primary', 1, 4, '提取关键信息，能制定简单学习计划并执行。', true),
  ('scheme_p5', '小学五年级', 'primary', 1, 5, '多步骤问题解决，项目式学习体验。', true),
  ('scheme_p6', '小学六年级', 'primary', 1, 6, '综合运用知识解决实际问题，为初中衔接。', true)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, stage = EXCLUDED.stage, stage_sort = EXCLUDED.stage_sort,
  sort_order = EXCLUDED.sort_order, description = EXCLUDED.description, is_builtin = true;

DELETE FROM plan_scheme_dimensions WHERE scheme_id IN
  ('scheme_p1', 'scheme_p2', 'scheme_p3', 'scheme_p4', 'scheme_p5', 'scheme_p6');

-- 一年级
INSERT INTO plan_scheme_dimensions (id, scheme_id, name, sort_order) VALUES
  ('schm_p1_1', 'scheme_p1', '语文', 1),
  ('schm_p1_2', 'scheme_p1', '数学', 2),
  ('schm_p1_3', 'scheme_p1', '科学/常识', 3),
  ('schm_p1_4', 'scheme_p1', '艺术体育', 4),
  ('schm_p1_5', 'scheme_p1', '品德与习惯', 5);

INSERT INTO plan_scheme_items (id, dimension_id, content, expected_level, concept_id, sort_order) VALUES
  ('schi_p1_1_1', 'schm_p1_1', '拼音、基础汉字、简单词句、朗读与口语交际',
   '能正确拼读；认识常用字并书写规范；能读通短句、表达完整意思', 'zi_ri', 1),
  ('schi_p1_2_1', 'schm_p1_2', '20以内数与加减法、认识图形、简单比较与分类、认识钟表与人民币',
   '能进行基础口算；辨认常见图形；理解简单数量关系', 'count_objects', 1),
  ('schi_p1_3_1', 'schm_p1_3', '校园与家庭环境、动植物初步认识、季节与天气',
   '能观察并描述身边现象；养成基本安全与卫生意识', 'co_weather_log', 1),
  ('schi_p1_4_1', 'schm_p1_4', '音乐节奏、简单美术表现、基本体能活动',
   '乐于参与；能完成简单动作与作品', NULL, 1),
  ('schi_p1_5_1', 'schm_p1_5', '课堂规则、同伴交往、时间与物品管理',
   '能遵守基本规则；在提醒下完成简单任务', 'st_take_turns', 1);

-- 二年级
INSERT INTO plan_scheme_dimensions (id, scheme_id, name, sort_order) VALUES
  ('schm_p2_1', 'scheme_p2', '语文', 1),
  ('schm_p2_2', 'scheme_p2', '数学', 2),
  ('schm_p2_3', 'scheme_p2', '科学/常识', 3),
  ('schm_p2_4', 'scheme_p2', '艺术体育', 4),
  ('schm_p2_5', 'scheme_p2', '品德与习惯', 5);

INSERT INTO plan_scheme_items (id, dimension_id, content, expected_level, concept_id, sort_order) VALUES
  ('schi_p2_1_1', 'schm_p2_1', '常用汉字扩展、词语积累、短文阅读、看图写话/短句写作',
   '阅读简单短文并回答问题；能写几句通顺的话', NULL, 1),
  ('schi_p2_2_1', 'schm_p2_2', '100以内数与运算、表内乘除初步、长度与时间单位初步',
   '口算与笔算更熟练；能解决一步简单应用题', NULL, 1),
  ('schi_p2_3_1', 'schm_p2_3', '生活材料、简单实验观察、动植物生长',
   '能提出简单问题并参与观察活动', NULL, 1),
  ('schi_p2_4_1', 'schm_p2_4', '节奏与旋律感受、造型与色彩、跑跳投基础',
   '动作协调性提高；能表达简单感受', NULL, 1),
  ('schi_p2_5_1', 'schm_p2_5', '责任意识、合作完成任务',
   '能独立完成部分学习与生活任务', 'st_take_turns', 1);

-- 三年级
INSERT INTO plan_scheme_dimensions (id, scheme_id, name, sort_order) VALUES
  ('schm_p3_1', 'scheme_p3', '语文', 1),
  ('schm_p3_2', 'scheme_p3', '数学', 2),
  ('schm_p3_3', 'scheme_p3', '科学', 3),
  ('schm_p3_4', 'scheme_p3', '英语（如开设）', 4),
  ('schm_p3_5', 'scheme_p3', '综合素养', 5);

INSERT INTO plan_scheme_items (id, dimension_id, content, expected_level, concept_id, sort_order) VALUES
  ('schi_p3_1_1', 'schm_p3_1', '段落阅读、概括主要内容、习作起步、口头表达',
   '能理解段落大意；能写结构完整的短文', NULL, 1),
  ('schi_p3_2_1', 'schm_p3_2', '万以内数、四则运算、周长面积初步、分数初步认识',
   '能进行较复杂计算；理解基本图形与数量关系', 'fraction', 1),
  ('schi_p3_3_1', 'schm_p3_3', '植物与动物特征、材料与运动、简单实验记录',
   '能按步骤观察记录；形成初步证据意识', NULL, 1),
  ('schi_p3_4_1', 'schm_p3_4', '字母、基础词汇与日常问候句型',
   '能听懂并模仿简单表达', NULL, 1),
  ('schi_p3_5_1', 'schm_p3_5', '信息获取初步、劳动与安全教育',
   '能在指导下查找资料并完成简单实践任务', 'fire_safety', 1);

-- 四年级
INSERT INTO plan_scheme_dimensions (id, scheme_id, name, sort_order) VALUES
  ('schm_p4_1', 'scheme_p4', '语文', 1),
  ('schm_p4_2', 'scheme_p4', '数学', 2),
  ('schm_p4_3', 'scheme_p4', '科学', 3),
  ('schm_p4_4', 'scheme_p4', '英语', 4),
  ('schm_p4_5', 'scheme_p4', '综合素养', 5);

INSERT INTO plan_scheme_items (id, dimension_id, content, expected_level, concept_id, sort_order) VALUES
  ('schi_p4_1_1', 'schm_p4_1', '说明性与叙事性文本阅读、提取关键信息、习作条理化',
   '能抓住要点复述；作文有较清晰结构', 'read_notice', 1),
  ('schi_p4_2_1', 'schm_p4_2', '大数认识、多位数运算、小数初步、图形与统计初步',
   '能选择合适方法解题；能读懂简单图表', 'statistics', 1),
  ('schi_p4_3_1', 'schm_p4_3', '电与磁初步、地球与空间初步、科学探究过程',
   '能提出假设并做对比观察', NULL, 1),
  ('schi_p4_4_1', 'schm_p4_4', '日常主题词汇、基础句型与短对话',
   '能进行简单情境交流与阅读短句', NULL, 1),
  ('schi_p4_5_1', 'schm_p4_5', '自主学习习惯、团队协作',
   '能制定简单学习计划并执行', NULL, 1);

-- 五年级
INSERT INTO plan_scheme_dimensions (id, scheme_id, name, sort_order) VALUES
  ('schm_p5_1', 'scheme_p5', '语文', 1),
  ('schm_p5_2', 'scheme_p5', '数学', 2),
  ('schm_p5_3', 'scheme_p5', '科学', 3),
  ('schm_p5_4', 'scheme_p5', '英语', 4),
  ('schm_p5_5', 'scheme_p5', '综合素养', 5);

INSERT INTO plan_scheme_items (id, dimension_id, content, expected_level, concept_id, sort_order) VALUES
  ('schi_p5_1_1', 'schm_p5_1', '多种文体阅读、概括与简单推断、说明与记叙写作',
   '能理解作者表达意图的表层线索；能围绕主题写作', NULL, 1),
  ('schi_p5_2_1', 'schm_p5_2', '分数小数运算、体积与面积综合、简易方程、统计图表',
   '能分析较复杂的数量关系；解决多步骤问题', 'fraction', 1),
  ('schi_p5_3_1', 'schm_p5_3', '人体与健康、能量与运动、物质变化初步',
   '能解释常见现象并联系生活', 'li_food_label', 1),
  ('schi_p5_4_1', 'schm_p5_4', '阅读短文、基础写作与听说综合运用',
   '能理解短文主旨并完成简单书面表达', NULL, 1),
  ('schi_p5_5_1', 'schm_p5_5', '信息辨别初步、项目式学习体验',
   '能合作完成主题探究并展示成果', NULL, 1);

-- 六年级
INSERT INTO plan_scheme_dimensions (id, scheme_id, name, sort_order) VALUES
  ('schm_p6_1', 'scheme_p6', '语文', 1),
  ('schm_p6_2', 'scheme_p6', '数学', 2),
  ('schm_p6_3', 'scheme_p6', '科学', 3),
  ('schm_p6_4', 'scheme_p6', '英语', 4),
  ('schm_p6_5', 'scheme_p6', '综合素养', 5);

INSERT INTO plan_scheme_items (id, dimension_id, content, expected_level, concept_id, sort_order) VALUES
  ('schi_p6_1_1', 'schm_p6_1', '阅读理解综合训练、表达与论述萌芽、写作完整性',
   '能独立阅读并形成观点；写作逻辑较清楚', NULL, 1),
  ('schi_p6_2_1', 'schm_p6_2', '比与比例、圆与百分数、综合应用问题、代数思维准备',
   '能综合运用知识解决实际问题；为初中数学衔接', 'math_ratio', 1),
  ('schi_p6_3_1', 'schm_p6_3', '系统梳理生命、物质、地球与技术主题',
   '能进行较完整的探究与总结', NULL, 1),
  ('schi_p6_4_1', 'schm_p6_4', '语篇阅读、基础语法综合、口头与书面表达',
   '能在熟悉话题上进行较连贯表达', NULL, 1),
  ('schi_p6_5_1', 'schm_p6_5', '自我管理、升学衔接准备',
   '具备初步自主学习与复盘能力', 'se_review_done', 1);

-- ── 初中（初一至初三） ────────────────────────────────────────────────
INSERT INTO plan_schemes (id, name, stage, stage_sort, sort_order, description, is_builtin) VALUES
  ('scheme_j1', '初一', 'junior', 2, 1, '建立分科知识体系，发展逻辑思维、实验探究与表达论证能力。', true),
  ('scheme_j2', '初二', 'junior', 2, 2, '函数与方程建模，观点表达更清晰。', true),
  ('scheme_j3', '初三', 'junior', 2, 3, '知识体系整合，综合解题与价值判断。', true)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, stage = EXCLUDED.stage, stage_sort = EXCLUDED.stage_sort,
  sort_order = EXCLUDED.sort_order, description = EXCLUDED.description, is_builtin = true;

DELETE FROM plan_scheme_dimensions WHERE scheme_id IN ('scheme_j1', 'scheme_j2', 'scheme_j3');

-- 初一
INSERT INTO plan_scheme_dimensions (id, scheme_id, name, sort_order) VALUES
  ('schm_j1_1', 'scheme_j1', '语文', 1),
  ('schm_j1_2', 'scheme_j1', '数学', 2),
  ('schm_j1_3', 'scheme_j1', '英语', 3),
  ('schm_j1_4', 'scheme_j1', '科学/物理化学生物', 4),
  ('schm_j1_5', 'scheme_j1', '历史地理道德与法治', 5);

INSERT INTO plan_scheme_items (id, dimension_id, content, expected_level, concept_id, sort_order) VALUES
  ('schi_j1_1_1', 'schm_j1_1', '文言文入门、现代文阅读、写作结构训练',
   '能理解常见文言词句；能写有中心、有条理的文章', 'classic_letter', 1),
  ('schi_j1_2_1', 'schm_j1_2', '有理数、整式、一次方程、几何初步',
   '掌握代数基本运算；建立空间与图形观念', NULL, 1),
  ('schi_j1_3_1', 'schm_j1_3', '基础语法系统化、听说读写综合',
   '能进行日常交流；阅读并理解简短语篇', NULL, 1),
  ('schi_j1_4_1', 'schm_j1_4', '科学方法、生命系统基础、物质与运动入门（按课程设置）',
   '能进行规范观察与简单实验', NULL, 1),
  ('schi_j1_5_1', 'schm_j1_5', '中国古代史与世界古代史基础、地图与区域认知、公民意识',
   '能建立时空框架；理解基本社会规则', 'his_family_story', 1);

-- 初二
INSERT INTO plan_scheme_dimensions (id, scheme_id, name, sort_order) VALUES
  ('schm_j2_1', 'scheme_j2', '语文', 1),
  ('schm_j2_2', 'scheme_j2', '数学', 2),
  ('schm_j2_3', 'scheme_j2', '英语', 3),
  ('schm_j2_4', 'scheme_j2', '物理/化学/生物', 4),
  ('schm_j2_5', 'scheme_j2', '历史地理道德与法治', 5);

INSERT INTO plan_scheme_items (id, dimension_id, content, expected_level, concept_id, sort_order) VALUES
  ('schi_j2_1_1', 'schm_j2_1', '文言文与现代文并进、议论与说明表达',
   '能分析文本内容与写法；观点表达更清晰', NULL, 1),
  ('schi_j2_2_1', 'schm_j2_2', '一次函数、全等与相似初步、实数与方程组',
   '能用函数与方程建模简单问题', 'th_model_condition', 1),
  ('schi_j2_3_1', 'schm_j2_3', '复杂句型、阅读理解与书面表达提升',
   '能理解中等难度文本并完成写作任务', NULL, 1),
  ('schi_j2_4_1', 'schm_j2_4', '力学或物质基础、实验设计与数据分析',
   '能解释现象背后的基本原理', NULL, 1),
  ('schi_j2_5_1', 'schm_j2_5', '近现代史脉络、自然与人文地理、法律常识',
   '能进行因果分析与区域比较', NULL, 1);

-- 初三
INSERT INTO plan_scheme_dimensions (id, scheme_id, name, sort_order) VALUES
  ('schm_j3_1', 'scheme_j3', '语文', 1),
  ('schm_j3_2', 'scheme_j3', '数学', 2),
  ('schm_j3_3', 'scheme_j3', '英语', 3),
  ('schm_j3_4', 'scheme_j3', '物理/化学/生物', 4),
  ('schm_j3_5', 'scheme_j3', '历史地理道德与法治', 5);

INSERT INTO plan_scheme_items (id, dimension_id, content, expected_level, concept_id, sort_order) VALUES
  ('schi_j3_1_1', 'schm_j3_1', '综合阅读、写作强化、古今文本联系',
   '能进行较深入理解与规范表达', NULL, 1),
  ('schi_j3_2_1', 'schm_j3_2', '二次函数、圆与概率统计基础、综合解题',
   '能综合运用多知识点解决问题', NULL, 1),
  ('schi_j3_3_1', 'schm_j3_3', '中考水平听说读写综合能力',
   '能在熟悉与半熟悉语境中准确表达', NULL, 1),
  ('schi_j3_4_1', 'schm_j3_4', '核心概念整合与实验能力提升',
   '能进行规范实验分析与结论表述', NULL, 1),
  ('schi_j3_5_1', 'schm_j3_5', '知识体系整合、社会议题理解',
   '能基于事实进行分析与价值判断', NULL, 1);

-- ── 高中（高一至高三） ────────────────────────────────────────────────
INSERT INTO plan_schemes (id, name, stage, stage_sort, sort_order, description, is_builtin) VALUES
  ('scheme_g1', '高一', 'senior', 3, 1, '深化学科理解与抽象思维，发展研究性学习与批判性思考。', true),
  ('scheme_g2', '高二', 'senior', 3, 2, '较复杂推理与模型应用，课题研究与证据意识。', true),
  ('scheme_g3', '高三', 'senior', 3, 3, '知识体系整合与生涯规划。', true)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, stage = EXCLUDED.stage, stage_sort = EXCLUDED.stage_sort,
  sort_order = EXCLUDED.sort_order, description = EXCLUDED.description, is_builtin = true;

DELETE FROM plan_scheme_dimensions WHERE scheme_id IN ('scheme_g1', 'scheme_g2', 'scheme_g3');

-- 高一
INSERT INTO plan_scheme_dimensions (id, scheme_id, name, sort_order) VALUES
  ('schm_g1_1', 'scheme_g1', '语文', 1),
  ('schm_g1_2', 'scheme_g1', '数学', 2),
  ('schm_g1_3', 'scheme_g1', '英语', 3),
  ('schm_g1_4', 'scheme_g1', '物理/化学/生物', 4),
  ('schm_g1_5', 'scheme_g1', '历史/地理/政治', 5),
  ('schm_g1_6', 'scheme_g1', '通用能力', 6);

INSERT INTO plan_scheme_items (id, dimension_id, content, expected_level, concept_id, sort_order) VALUES
  ('schi_g1_1_1', 'schm_g1_1', '文学作品鉴赏、论述类文本阅读、写作思辨性提升',
   '能分析文本结构与观点；形成有依据的表达', NULL, 1),
  ('schi_g1_2_1', 'schm_g1_2', '集合与函数、立体几何初步、解析几何入门、统计与概率',
   '理解抽象概念并进行基本证明与建模', NULL, 1),
  ('schi_g1_3_1', 'schm_g1_3', '语篇理解、应用写作、口语表达',
   '能处理较长文本并进行清晰表达', NULL, 1),
  ('schi_g1_4_1', 'schm_g1_4', '运动与力、物质结构与反应、细胞与遗传基础',
   '建立学科核心概念，能进行定量与定性分析', NULL, 1),
  ('schi_g1_5_1', 'schm_g1_5', '中外历史专题、自然与人文地理规律、经济政治思想基础',
   '能从多角度解释历史与现实问题', NULL, 1),
  ('schi_g1_6_1', 'schm_g1_6', '学习策略、信息检索、实验与探究规范',
   '形成自主学习与初步研究意识', 'th_claim_evidence', 1);

-- 高二
INSERT INTO plan_scheme_dimensions (id, scheme_id, name, sort_order) VALUES
  ('schm_g2_1', 'scheme_g2', '语文', 1),
  ('schm_g2_2', 'scheme_g2', '数学', 2),
  ('schm_g2_3', 'scheme_g2', '英语', 3),
  ('schm_g2_4', 'scheme_g2', '选考/主修学科', 4),
  ('schm_g2_5', 'scheme_g2', '研究与实践', 5);

INSERT INTO plan_scheme_items (id, dimension_id, content, expected_level, concept_id, sort_order) VALUES
  ('schi_g2_1_1', 'schm_g2_1', '文化经典阅读、复杂论证写作',
   '能进行文本比较与深度分析', NULL, 1),
  ('schi_g2_2_1', 'schm_g2_2', '导数初步、数列、概率统计深化、综合问题',
   '能进行较复杂推理与模型应用', NULL, 1),
  ('schi_g2_3_1', 'schm_g2_3', '学术性阅读与表达初步',
   '能围绕主题进行论述与交流', NULL, 1),
  ('schi_g2_4_1', 'schm_g2_4', '在物化生史地政等方向上深化模块学习',
   '形成学科优势与知识网络', NULL, 1),
  ('schi_g2_5_1', 'schm_g2_5', '课题研究、实验报告、社会实践',
   '能提出问题、收集证据并形成结论', NULL, 1);

-- 高三
INSERT INTO plan_scheme_dimensions (id, scheme_id, name, sort_order) VALUES
  ('schm_g3_1', 'scheme_g3', '语文', 1),
  ('schm_g3_2', 'scheme_g3', '数学', 2),
  ('schm_g3_3', 'scheme_g3', '英语', 3),
  ('schm_g3_4', 'scheme_g3', '选考/主修学科', 4),
  ('schm_g3_5', 'scheme_g3', '生涯规划', 5);

INSERT INTO plan_scheme_items (id, dimension_id, content, expected_level, concept_id, sort_order) VALUES
  ('schi_g3_1_1', 'schm_g3_1', '综合阅读与写作能力整合',
   '能稳定输出高质量理解与表达', NULL, 1),
  ('schi_g3_2_1', 'schm_g3_2', '知识体系整合与综合应用',
   '能灵活迁移方法解决新问题', NULL, 1),
  ('schi_g3_3_1', 'schm_g3_3', '综合语言运用能力巩固',
   '能准确、得体地完成复杂任务', NULL, 1),
  ('schi_g3_4_1', 'schm_g3_4', '核心考点与能力要求整合',
   '达到阶段性学业评价要求', NULL, 1),
  ('schi_g3_5_1', 'schm_g3_5', '专业选择、升学准备、自我认知',
   '能结合兴趣与能力做出理性规划', NULL, 1);

-- ── 大学（大一至大四） ────────────────────────────────────────────────
INSERT INTO plan_schemes (id, name, stage, stage_sort, sort_order, description, is_builtin) VALUES
  ('scheme_c1', '大一', 'college', 4, 1, '完成通识与专业基础教育，建立自主学习与自我管理习惯。', true),
  ('scheme_c2', '大二', 'college', 4, 2, '专业基础与方法训练，能在团队中承担明确角色并交付成果。', true),
  ('scheme_c3', '大三', 'college', 4, 3, '专业核心与实习实训，明确发展路径并积累支撑材料。', true),
  ('scheme_c4', '大四', 'college', 4, 4, '综合训练与专业整合，达到初入职场或继续深造的准备度。', true)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, stage = EXCLUDED.stage, stage_sort = EXCLUDED.stage_sort,
  sort_order = EXCLUDED.sort_order, description = EXCLUDED.description, is_builtin = true;

DELETE FROM plan_scheme_dimensions WHERE scheme_id IN
  ('scheme_c1', 'scheme_c2', 'scheme_c3', 'scheme_c4');

-- 大一
INSERT INTO plan_scheme_dimensions (id, scheme_id, name, sort_order) VALUES
  ('schm_c1_1', 'scheme_c1', '通识教育', 1),
  ('schm_c1_2', 'scheme_c1', '专业导论', 2),
  ('schm_c1_3', 'scheme_c1', '实践能力', 3),
  ('schm_c1_4', 'scheme_c1', '自我发展', 4);

INSERT INTO plan_scheme_items (id, dimension_id, content, expected_level, concept_id, sort_order) VALUES
  ('schi_c1_1_1', 'schm_c1_1', '大学写作、数学/逻辑基础、信息素养、外语或跨文化交流',
   '适应大学学习方式；具备基本学术表达与检索能力', 'th_define_terms', 1),
  ('schi_c1_2_1', 'schm_c1_2', '学科概貌、核心概念、基本方法',
   '了解专业图景与发展方向', NULL, 1),
  ('schi_c1_3_1', 'schm_c1_3', '基础实验/实训/项目体验',
   '能在指导下完成基础任务', NULL, 1),
  ('schi_c1_4_1', 'schm_c1_4', '时间管理、学习规划、团队合作',
   '建立自主学习与自我管理习惯', 'se_review_done', 1);

-- 大二
INSERT INTO plan_scheme_dimensions (id, scheme_id, name, sort_order) VALUES
  ('schm_c2_1', 'scheme_c2', '专业基础课', 1),
  ('schm_c2_2', 'scheme_c2', '通识拓展', 2),
  ('schm_c2_3', 'scheme_c2', '方法训练', 3),
  ('schm_c2_4', 'scheme_c2', '项目实践', 4);

INSERT INTO plan_scheme_items (id, dimension_id, content, expected_level, concept_id, sort_order) VALUES
  ('schi_c2_1_1', 'schm_c2_1', '学科核心理论、方法与工具课程',
   '掌握专业基础知识并能解决典型问题', NULL, 1),
  ('schi_c2_2_1', 'schm_c2_2', '跨学科选修、人文社科或科学素养课程',
   '形成更宽广的知识视角', NULL, 1),
  ('schi_c2_3_1', 'schm_c2_3', '文献阅读、数据处理/实验技能/案例分析',
   '能规范地获取与处理信息', NULL, 1),
  ('schi_c2_4_1', 'schm_c2_4', '课程设计、小组项目',
   '能在团队中承担明确角色并交付成果', 'mk_sheet_tool', 1);

-- 大三
INSERT INTO plan_scheme_dimensions (id, scheme_id, name, sort_order) VALUES
  ('schm_c3_1', 'scheme_c3', '专业核心课', 1),
  ('schm_c3_2', 'scheme_c3', '研究/工程能力', 2),
  ('schm_c3_3', 'scheme_c3', '实习实训', 3),
  ('schm_c3_4', 'scheme_c3', '职业/升学准备', 4);

INSERT INTO plan_scheme_items (id, dimension_id, content, expected_level, concept_id, sort_order) VALUES
  ('schi_c3_1_1', 'schm_c3_1', '方向性核心课程、专题课程',
   '深入理解专业关键问题与前沿基础', NULL, 1),
  ('schi_c3_2_1', 'schm_c3_2', '研究方法、工程规范、创新实践',
   '能独立完成中等复杂度任务', NULL, 1),
  ('schi_c3_3_1', 'schm_c3_3', '企业/机构实践或科研训练',
   '将理论应用于真实场景，积累经验', NULL, 1),
  ('schi_c3_4_1', 'schm_c3_4', '作品集、实习总结、考研/就业规划',
   '明确发展路径并积累支撑材料', NULL, 1);

-- 大四
INSERT INTO plan_scheme_dimensions (id, scheme_id, name, sort_order) VALUES
  ('schm_c4_1', 'scheme_c4', '综合训练', 1),
  ('schm_c4_2', 'scheme_c4', '专业整合', 2),
  ('schm_c4_3', 'scheme_c4', '职业能力', 3),
  ('schm_c4_4', 'scheme_c4', '总结反思', 4);

INSERT INTO plan_scheme_items (id, dimension_id, content, expected_level, concept_id, sort_order) VALUES
  ('schi_c4_1_1', 'schm_c4_1', '毕业设计/毕业论文/综合实践',
   '能围绕真实问题完成系统性成果', NULL, 1),
  ('schi_c4_2_1', 'schm_c4_2', '知识融会贯通、跨课程综合应用',
   '形成完整的专业能力结构', NULL, 1),
  ('schi_c4_3_1', 'schm_c4_3', '沟通表达、项目管理、职业伦理',
   '达到初入职场或继续深造的准备度', NULL, 1),
  ('schi_c4_4_1', 'schm_c4_4', '学习复盘、能力评估、长期规划',
   '能清晰表述自身能力与发展方向', 'se_what_matters', 1);

-- ── 研究生（研一至研三，学术研究导向） ────────────────────────────────
INSERT INTO plan_schemes (id, name, stage, stage_sort, sort_order, description, is_builtin) VALUES
  ('scheme_r1', '研一', 'graduate', 5, 1, '学术研究导向：系统掌握理论框架与研究方法。', true),
  ('scheme_r2', '研二', 'graduate', 5, 2, '学术研究导向：独立推进研究环节并形成阶段性成果。', true),
  ('scheme_r3', '研三', 'graduate', 5, 3, '学术研究导向：学位论文凝练与答辩、发展规划。', true)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, stage = EXCLUDED.stage, stage_sort = EXCLUDED.stage_sort,
  sort_order = EXCLUDED.sort_order, description = EXCLUDED.description, is_builtin = true;

DELETE FROM plan_scheme_dimensions WHERE scheme_id IN ('scheme_r1', 'scheme_r2', 'scheme_r3');

-- 研一
INSERT INTO plan_scheme_dimensions (id, scheme_id, name, sort_order) VALUES
  ('schm_r1_1', 'scheme_r1', '理论基础', 1),
  ('schm_r1_2', 'scheme_r1', '研究方法', 2),
  ('schm_r1_3', 'scheme_r1', '学术训练', 3),
  ('schm_r1_4', 'scheme_r1', '选题准备', 4);

INSERT INTO plan_scheme_items (id, dimension_id, content, expected_level, concept_id, sort_order) VALUES
  ('schi_r1_1_1', 'schm_r1_1', '高阶专业课程、研究领域核心文献',
   '系统掌握本方向理论框架与关键问题', NULL, 1),
  ('schi_r1_2_1', 'schm_r1_2', '研究设计、文献综述、学术规范与伦理',
   '能检索、阅读并评述文献；理解研究范式', 'th_claim_evidence', 1),
  ('schi_r1_3_1', 'schm_r1_3', '研讨课、论文研读、实验/调研技能',
   '能参与学术讨论并提出有价值问题', NULL, 1),
  ('schi_r1_4_1', 'schm_r1_4', '确定研究兴趣与初步方向',
   '形成可行的研究问题雏形', NULL, 1);

-- 研二
INSERT INTO plan_scheme_dimensions (id, scheme_id, name, sort_order) VALUES
  ('schm_r2_1', 'scheme_r2', '专题研究', 1),
  ('schm_r2_2', 'scheme_r2', '研究实施', 2),
  ('schm_r2_3', 'scheme_r2', '学术产出', 3),
  ('schm_r2_4', 'scheme_r2', '协作与交流', 4);

INSERT INTO plan_scheme_items (id, dimension_id, content, expected_level, concept_id, sort_order) VALUES
  ('schi_r2_1_1', 'schm_r2_1', '围绕选题的深入文献与理论/技术攻关',
   '对研究问题具备较全面把握', NULL, 1),
  ('schi_r2_2_1', 'schm_r2_2', '实验、数据采集、建模、案例或田野工作',
   '能独立推进研究环节并处理常见问题', NULL, 1),
  ('schi_r2_3_1', 'schm_r2_3', '论文写作、会议交流、阶段性成果',
   '能形成规范的研究报告或论文初稿', NULL, 1),
  ('schi_r2_4_1', 'schm_r2_4', '参与课题组、学术汇报与同行反馈',
   '能回应质疑并改进研究设计', NULL, 1);

-- 研三
INSERT INTO plan_scheme_dimensions (id, scheme_id, name, sort_order) VALUES
  ('schm_r3_1', 'scheme_r3', '成果凝练', 1),
  ('schm_r3_2', 'scheme_r3', '创新贡献', 2),
  ('schm_r3_3', 'scheme_r3', '答辩与发表', 3),
  ('schm_r3_4', 'scheme_r3', '发展规划', 4);

INSERT INTO plan_scheme_items (id, dimension_id, content, expected_level, concept_id, sort_order) VALUES
  ('schi_r3_1_1', 'schm_r3_1', '学位论文撰写、研究结论提炼',
   '能形成逻辑严密、证据充分的学术成果', NULL, 1),
  ('schi_r3_2_1', 'schm_r3_2', '对领域问题提出新理解、方法或应用证据',
   '在限定范围内体现创新性与严谨性', NULL, 1),
  ('schi_r3_3_1', 'schm_r3_3', '论文答辩、投稿修改、成果展示',
   '能清晰阐述研究价值与局限', NULL, 1),
  ('schi_r3_4_1', 'schm_r3_4', '博士深造/学术岗位/研发岗位准备',
   '明确后续学术或职业发展方向', NULL, 1);

-- ── 硕士（硕一至硕三，专业实践导向） ─────────────────────────────────
INSERT INTO plan_schemes (id, name, stage, stage_sort, sort_order, description, is_builtin) VALUES
  ('scheme_m1', '硕一', 'master', 6, 1, '专业实践导向：掌握岗位相关核心知识与工具。', true),
  ('scheme_m2', '硕二', 'master', 6, 2, '专业实践导向：在真实约束下推进项目并交付阶段成果。', true),
  ('scheme_m3', '硕三', 'master', 6, 3, '专业实践导向：毕业实践/论文与职业交付能力。', true)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, stage = EXCLUDED.stage, stage_sort = EXCLUDED.stage_sort,
  sort_order = EXCLUDED.sort_order, description = EXCLUDED.description, is_builtin = true;

DELETE FROM plan_scheme_dimensions WHERE scheme_id IN ('scheme_m1', 'scheme_m2', 'scheme_m3');

-- 硕一
INSERT INTO plan_scheme_dimensions (id, scheme_id, name, sort_order) VALUES
  ('schm_m1_1', 'scheme_m1', '专业核心课', 1),
  ('schm_m1_2', 'scheme_m1', '方法与工具', 2),
  ('schm_m1_3', 'scheme_m1', '案例学习', 3),
  ('schm_m1_4', 'scheme_m1', '职业素养', 4);

INSERT INTO plan_scheme_items (id, dimension_id, content, expected_level, concept_id, sort_order) VALUES
  ('schi_m1_1_1', 'schm_m1_1', '面向实践的高阶课程、行业知识框架',
   '掌握岗位相关核心知识与工具', NULL, 1),
  ('schi_m1_2_1', 'schm_m1_2', '数据分析/设计/管理/工程方法等（依专业而定）',
   '能运用专业方法分析实际问题', NULL, 1),
  ('schi_m1_3_1', 'schm_m1_3', '行业案例、最佳实践、标准规范',
   '能从案例中抽象可迁移经验', NULL, 1),
  ('schi_m1_4_1', 'schm_m1_4', '团队协作、沟通表达、职业伦理',
   '适应专业场景的协作与沟通要求', NULL, 1);

-- 硕二
INSERT INTO plan_scheme_dimensions (id, scheme_id, name, sort_order) VALUES
  ('schm_m2_1', 'scheme_m2', '专业深化', 1),
  ('schm_m2_2', 'scheme_m2', '实践训练', 2),
  ('schm_m2_3', 'scheme_m2', '综合能力', 3),
  ('schm_m2_4', 'scheme_m2', '成果准备', 4);

INSERT INTO plan_scheme_items (id, dimension_id, content, expected_level, concept_id, sort_order) VALUES
  ('schi_m2_1_1', 'schm_m2_1', '方向选修、前沿应用专题',
   '在细分方向形成较强应用能力', NULL, 1),
  ('schi_m2_2_1', 'schm_m2_2', '企业实践、项目实训、实验/设计/咨询任务',
   '能在真实约束下推进项目并交付阶段成果', NULL, 1),
  ('schi_m2_3_1', 'schm_m2_3', '需求分析、方案设计、风险与质量意识',
   '能权衡成本、进度与质量做出决策', NULL, 1),
  ('schi_m2_4_1', 'schm_m2_4', '实践报告、项目文档、作品集积累',
   '形成可展示的专业成果', NULL, 1);

-- 硕三
INSERT INTO plan_scheme_dimensions (id, scheme_id, name, sort_order) VALUES
  ('schm_m3_1', 'scheme_m3', '毕业实践/论文', 1),
  ('schm_m3_2', 'scheme_m3', '职业交付能力', 2),
  ('schm_m3_3', 'scheme_m3', '行业衔接', 3),
  ('schm_m3_4', 'scheme_m3', '持续成长', 4);

INSERT INTO plan_scheme_items (id, dimension_id, content, expected_level, concept_id, sort_order) VALUES
  ('schi_m3_1_1', 'schm_m3_1', '应用研究、工程项目总结或专业学位论文',
   '能系统总结问题、方法、过程与结果', NULL, 1),
  ('schi_m3_2_1', 'schm_m3_2', '方案落地、复盘优化、跨角色沟通',
   '具备独立负责模块或项目的能力', NULL, 1),
  ('schi_m3_3_1', 'schm_m3_3', '求职/岗位胜任/创业或在职提升准备',
   '达到目标岗位的专业与综合能力要求', NULL, 1),
  ('schi_m3_4_1', 'schm_m3_4', '终身学习计划、专业网络与发展路径',
   '能规划持续提升方向与学习资源', NULL, 1);
