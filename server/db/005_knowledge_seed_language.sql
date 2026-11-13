-- 语领域：从认字到读懂公共文本，同一概念在不同年龄只换呈现深度。
-- 数据来源：app/lib/knowledge/catalog/language.dart，两边改动要同步。

INSERT INTO knowledge_domains
  (id, name, glyph, color, category_id, sort_order)
VALUES
  ('language', '语', '字', '#8C4A2F', 'education', 1)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  glyph = EXCLUDED.glyph,
  color = EXCLUDED.color,
  category_id = EXCLUDED.category_id,
  sort_order = EXCLUDED.sort_order;

INSERT INTO knowledge_concepts (id, domain_id, depth, sort_order)
VALUES
  ('zi_ri', 'language', 0, 1),
  ('read_notice', 'language', 1, 2),
  ('own_note', 'language', 2, 3)
ON CONFLICT (id) DO UPDATE SET
  domain_id = EXCLUDED.domain_id,
  depth = EXCLUDED.depth,
  sort_order = EXCLUDED.sort_order;

INSERT INTO knowledge_concept_prerequisites (concept_id, prerequisite_id)
VALUES
  ('read_notice', 'zi_ri'),
  ('own_note', 'read_notice')
ON CONFLICT (concept_id, prerequisite_id) DO NOTHING;

INSERT INTO knowledge_variants
  (concept_id, age_band_id, topic, glyph, doing, praise, check_question, answer, note)
VALUES
  (
    'zi_ri',
    'toddler',
    '认一认「日」',
    '日',
    '指出太阳是「日」',
    '你能指出太阳是「日」',
    '窗边的太阳和纸上的太阳，都是「日」吗？',
    '都是。同一个字可以在不同地方认出来。',
    '先看窗外的太阳，再指纸上的字。'
  ),
  (
    'zi_ri',
    'lower_primary',
    '用「日」写一句话',
    '日',
    '说一句带「日」的话，例如「今天有太阳」',
    '你能用「日」说一句话',
    '「日」在这句里是太阳，还是日子？',
    '两种意思都有，要看句子在说哪一天。',
    '写完读给身边的人听。'
  ),
  (
    'zi_ri',
    'upper_primary',
    '从一段里读出「日」',
    '日',
    '读一段短文，标出写太阳的句子',
    '你能在一段里找出写太阳的句子',
    '哪一句在写光和热？',
    '写光亮和温度的那一句。',
    '不确定时，先把写光亮的词圈出来。'
  ),
  (
    'read_notice',
    'lower_primary',
    '读懂一则校园通知',
    NULL,
    '在通知里找到时间和地点',
    '你能找到通知里的时间和地点',
    '通知要你什么时候到哪里？',
    '时间和地点各有一处。',
    '先找冒号后面那两样。'
  ),
  (
    'read_notice',
    'upper_primary',
    '找出通知要带的材料',
    NULL,
    '在通知里圈出需要带的东西',
    '你能在通知里找齐要带的东西',
    '如果漏了一样，会发生什么？',
    '可能办不成，需要回去拿。',
    NULL
  ),
  (
    'read_notice',
    'middle_school',
    '读出通知里的条件',
    NULL,
    '写出这则通知的适用对象和截止时间',
    '你能写出通知的条件',
    '谁需要办，办到什么时候？',
    '适用对象和截止时间各一句。',
    '条件常写在「凡」「须」「前」这些词附近。'
  ),
  (
    'read_notice',
    'beyond_school',
    '读懂一则公共通告',
    NULL,
    '标出事项、时间、地点和咨询方式',
    '你能把公共通告的要素找到',
    '这条通告让人做什么？',
    '先看动词，再看时间和地点。',
    '找不到咨询方式时，写下缺的那一项。'
  ),
  (
    'own_note',
    'upper_primary',
    '写一句自己的看法',
    NULL,
    '写一句你为什么这么想',
    '你能写出自己的看法和理由',
    '你的理由来自看到的哪一处？',
    '说出具体的一处，不是只说「我觉得」。',
    NULL
  ),
  (
    'own_note',
    'middle_school',
    '写一段有出处的笔记',
    NULL,
    '摘一句原文，并写下它出自哪里',
    '你能写出带出处的笔记',
    '这句话你能在哪里再找到？',
    '写清书名、页码或链接。',
    '转述不能代替原句。'
  ),
  (
    'own_note',
    'high_school',
    '写出结论依赖的条件',
    NULL,
    '给你的结论补一句「在什么条件下成立」',
    '你能写出结论成立的条件',
    '换一个条件，结论还成立吗？',
    '把条件写在结论旁边，再试着换掉它。',
    NULL
  ),
  (
    'own_note',
    'college',
    '文献摘录和出处',
    NULL,
    '摘一段文献，标出作者、年份和页码',
    '你能写出可复核的文献摘录',
    '别人照这条信息能找到原文吗？',
    '作者、年份、页码各一处。',
    NULL
  ),
  (
    'own_note',
    'beyond_school',
    '记一条只给自己的反思',
    NULL,
    '写一句今天更知道自己什么',
    '你能写一句只给自己的反思',
    '这句不用给别人看，也不用打分。',
    '留给自己就好。',
    '只存在本机，可随时删。'
  )
ON CONFLICT (concept_id, age_band_id) DO UPDATE SET
  topic = EXCLUDED.topic,
  glyph = EXCLUDED.glyph,
  doing = EXCLUDED.doing,
  praise = EXCLUDED.praise,
  check_question = EXCLUDED.check_question,
  answer = EXCLUDED.answer,
  note = EXCLUDED.note;
