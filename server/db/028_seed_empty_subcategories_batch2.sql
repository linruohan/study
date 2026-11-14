-- 空子分类灌库第二批（P4 内容运营继续）:
-- 再取九个空子分类，年龄段小学低年级到高中（不动蒙学档）。
-- 结构与知识点展开规则同 021–027（008 规则 + 认知层级），幂等。

INSERT INTO knowledge_concepts (id, category_id, depth, sort_order) VALUES
  ('co_coin_tally',        'co_stats',           0, 1),
  ('co_quad_sample',       'co_climate_eco',     0, 1),
  ('ethics_two_camps',     'edu_thought_tradition', 0, 1),
  ('mil_know_self',        'edu_mil_classic',    0, 1),
  ('exp_why_simple_logo',  'exp_visual_design',  0, 1),
  ('gv_queue_order',       'gv_sociology',       0, 1),
  ('gv_news_bargain',      'gv_ir',              0, 1),
  ('li_care_temp',         'li_nursing',         0, 1),
  ('se_quiet_ten_minutes', 'se_spiritual',       0, 1)
ON CONFLICT (id) DO UPDATE SET
  category_id = EXCLUDED.category_id, depth = EXCLUDED.depth, sort_order = EXCLUDED.sort_order;

INSERT INTO knowledge_variants (concept_id, age_band_id, topic, doing, praise, check_question, answer, note) VALUES
  ('co_coin_tally', 'upper_primary',
   '掷多了会出现规律',
   '掷硬币二十次记下正反面，数一数各出现几次',
   '你能掷二十次并数清各出现了几次',
   '前五次都是正面，第六次一定反面吗？',
   '不一定。每次抛掷都是独立的，前面结果不影响后面。',
   '次数太少看不出规律；想谈「大概率」至少要几十次。'),
  ('co_quad_sample', 'middle_school',
   '一平米里的生态',
   '在草地划一平米样方，数出里面有几类动植物并拍照记录',
   '你能数清一平米里的生物种类并记录',
   '为什么要固定一平米，随眼光看不行吗？',
   '固定范围才能比较：今天和下周、这里和那里，量纲一致才可比。',
   '记下日期、地点和天气；不确定的物种先拍照回头查。'),
  ('ethics_two_camps', 'high_school',
   '一条道德难题的两派',
   '找一个经典两难问题，各写一派的理由和反驳',
   '你能把两派的理由和反驳都写清楚',
   '两派都讲得通，是不是就没有对错了？',
   '两派只是理由不同：一个看结果，一个看规则；先说清各自站在什么前提。',
   '先复述对方最强理由再反驳，这是思想史的基本功。'),
  ('mil_know_self', 'high_school',
   '知彼知己的另一半',
   '读一篇兵法选段，把它用到一次比赛或项目复盘里',
   '你能把兵法原则用到自己的复盘里',
   '「知彼知己」里哪一半更难做到？',
   '知己更难：高估自己和低估自己都常见，要用记录而不是感觉。',
   '复盘写三行：想赢什么、实际怎样、下次改哪一步。'),
  ('exp_why_simple_logo', 'upper_primary',
   '标识为什么一眼能认出',
   '找五个常见标识，说说它们共同用了什么办法让人一眼认出',
   '你能说出常见标识里用的设计办法',
   '把标识画得很复杂，会怎么样？',
   '远看和快看时复杂图形糊成一团；对比强、形状少的才认得出。',
   '试一次：把自己的设计缩到指甲盖大小再检查。'),
  ('gv_queue_order', 'middle_school',
   '一次排队的秩序',
   '观察一次排队的规则：谁定的、怎么执行、插队会怎样',
   '你能观察并说清一次排队里的秩序',
   '没人管的时候，队伍靠什么维持？',
   '靠大家的共识和被插队者的反应；规则一旦不被执行就散了。',
   '记录三个细节：规则、执行、例外怎么处理。'),
  ('gv_news_bargain', 'high_school',
   '一条国际新闻里的博弈',
   '挑一条国际新闻，写出各方的目标、筹码和底线',
   '你能把一条国际新闻写成本「谁想要什么、拿什么换」',
   '谈判桌上筹码和底线有什么不同？',
   '筹码是可以让步的东西，底线是让了就崩的东西；新闻里常常只露筹码。',
   '只写新闻里说过的，推测的部分标「推测」。'),
  ('li_care_temp', 'lower_primary',
   '照顾生病的人：量体温',
   '学会用体温计量一次体温，说出多少度算发烧',
   '你会量体温并说出发烧的界线',
   '量出来 38 度该先做什么？',
   '先告诉家里的大人；多喝水休息，反复升高要就医。',
   '量之前甩好体温计、擦干腋下；数值记在纸上别凭记性。'),
  ('se_quiet_ten_minutes', 'high_school',
   '安静十分钟',
   '每天安静坐十分钟只注意呼吸，坚持一周并记下感受变化',
   '你能安静十分钟并坚持一周记录',
   '走神了算失败吗？',
   '不算。发现自己走神、再回到呼吸，这正是练习本身。',
   '记录用一句话：今天走神几次、最难坐住的是哪几分钟。')
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
  'co_coin_tally','co_quad_sample','ethics_two_camps','mil_know_self',
  'exp_why_simple_logo','gv_queue_order','gv_news_bargain',
  'li_care_temp','se_quiet_ten_minutes'
)
ON CONFLICT (concept_id, age_band_id, degree_id, position) DO UPDATE SET
  point = EXCLUDED.point, cognitive_level = EXCLUDED.cognitive_level;
