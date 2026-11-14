-- 知识点挂认知层级：记忆→理解→应用→分析→评价→创新（布鲁姆六层）。
-- 存量知识点默认「记忆」，管理员编辑知识点时可逐条标注。

ALTER TABLE knowledge_variant_points
  ADD COLUMN IF NOT EXISTS cognitive_level text NOT NULL DEFAULT 'remember';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'knowledge_variant_points_cognitive_check'
  ) THEN
    ALTER TABLE knowledge_variant_points
      ADD CONSTRAINT knowledge_variant_points_cognitive_check
      CHECK (cognitive_level IN ('remember', 'understand', 'apply', 'analyze', 'evaluate', 'create'));
  END IF;
END $$;

COMMENT ON COLUMN knowledge_variant_points.cognitive_level
  IS '认知思维目标层次：remember/understand/apply/analyze/evaluate/create，由低到高';
