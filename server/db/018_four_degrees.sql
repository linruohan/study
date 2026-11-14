-- 认知程度扩为四档：入门 / 熟练 / 精通 / 创造。
-- 旧三档的对应关系（见 doc/开发指导文档.md「知识体系」）：
--   beginner 入门（原"尝试"层）、familiar 熟练（原"熟悉"层）、
--   advanced 精通（原"熟练/掌握"层）、creative 创造（新增）。

-- familiar 的中文口径由「熟悉」统一为「熟练」。
UPDATE knowledge_degrees SET label = '熟练' WHERE id = 'familiar';

-- 新增第四档「创造」：提出原创性问题或方案、产出知识增量。
INSERT INTO knowledge_degrees (id, label, sort_order)
VALUES ('creative', '创造', 4)
ON CONFLICT (id) DO NOTHING;
