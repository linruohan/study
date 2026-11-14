-- 统一知识树：取消「领域」层，知识直接挂在可嵌套的分类（父类/子类）上。
-- 1) 每个领域平移成其所属分类下的一个子类；id 沿用原领域 id，
--    若与现有分类 id 撞名（如种子里的根分类 life 与领域 life）则改用 cat_ 前缀。
-- 2) 知识 concepts 改为引用 category_id，删除 domain_id。
-- 3) 用户数据里的 domain_id 外键改为普通列。
-- 3) 引用 knowledge_domains 的全部外键改为普通列：值（分类 id）迁移后仍然
--    有效，不再强制引用。动态枚举，避免漏掉某张表或表不存在时报错。
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT conname, rel.relname AS tablename
    FROM pg_constraint c
    JOIN pg_class rel ON rel.oid = c.conrelid
    WHERE c.contype = 'f'
      AND c.confrelid = 'knowledge_domains'::regclass
  LOOP
    EXECUTE format('ALTER TABLE %I DROP CONSTRAINT %I', r.tablename, r.conname);
  END LOOP;
END $$;

-- 4) 删除 knowledge_domains 表。

-- 领域 → 新分类 id 的映射（临时表，事务结束自动消失）
CREATE TEMP TABLE domain_to_category AS
SELECT
  d.id AS domain_id,
  d.category_id AS parent_id,
  d.name,
  d.glyph,
  d.color,
  d.sort_order,
  CASE
    WHEN EXISTS (SELECT 1 FROM knowledge_categories c WHERE c.id = d.id)
      THEN 'cat_' || d.id
    ELSE d.id
  END AS new_category_id
FROM knowledge_domains d;

-- 领域平移成子类（描述字段按分类表约束置空串）
INSERT INTO knowledge_categories (id, name, question, ancient, modern, glyph, color, sort_order, parent_id)
SELECT
  m.new_category_id,
  m.name,
  '',
  '',
  '',
  m.glyph,
  m.color,
  m.sort_order,
  m.parent_id
FROM domain_to_category m;

-- 知识改挂分类
ALTER TABLE knowledge_concepts
  ADD COLUMN category_id text REFERENCES knowledge_categories (id);

UPDATE knowledge_concepts k
SET category_id = m.new_category_id
FROM domain_to_category m
WHERE m.domain_id = k.domain_id;

ALTER TABLE knowledge_concepts
  ALTER COLUMN category_id SET NOT NULL;

ALTER TABLE knowledge_concepts
  DROP COLUMN domain_id;

-- 删除领域层
DROP TABLE knowledge_domains;
