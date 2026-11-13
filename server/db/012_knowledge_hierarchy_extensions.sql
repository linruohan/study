-- 知识库层级与互动扩展（前向兼容）：
-- 1) 九大基类下支持子类型嵌套（通过父级引用）
-- 2) 知识点下细分章节（最基础知识单元）
-- 3) 知识点评论、纠错与审核积分

-- 子类型嵌套：允许在九大基类下创建子分类（可多级）
ALTER TABLE knowledge_categories
  ADD COLUMN IF NOT EXISTS parent_id text REFERENCES knowledge_categories (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS knowledge_categories_parent_idx
  ON knowledge_categories (parent_id, sort_order);

COMMENT ON COLUMN knowledge_categories.parent_id IS '父分类 id；为空表示九大基类，非空表示子类型（可嵌套）';

-- 章节：隶属于某年龄档/学习程度下的某个知识点（按 position 定位）
CREATE TABLE IF NOT EXISTS knowledge_variant_point_chapters (
  concept_id text NOT NULL,
  age_band_id text NOT NULL,
  degree_id text NOT NULL,
  point_position integer NOT NULL,
  chapter_position integer NOT NULL CHECK (chapter_position >= 1),
  title text NOT NULL,
  content text,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (concept_id, age_band_id, degree_id, point_position, chapter_position),
  FOREIGN KEY (concept_id, age_band_id, degree_id, point_position)
    REFERENCES knowledge_variant_points (concept_id, age_band_id, degree_id, position)
    ON DELETE CASCADE
);

COMMENT ON TABLE knowledge_variant_point_chapters IS '知识点章节：每个章节是最基础的知识单元';

-- 知识点评论
CREATE TABLE IF NOT EXISTS knowledge_point_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  concept_id text NOT NULL,
  age_band_id text NOT NULL,
  degree_id text NOT NULL,
  point_position integer NOT NULL,
  device_id uuid NOT NULL REFERENCES devices (id) ON DELETE CASCADE,
  body text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (concept_id, age_band_id, degree_id, point_position)
    REFERENCES knowledge_variant_points (concept_id, age_band_id, degree_id, position)
    ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS knowledge_point_comments_target_idx
  ON knowledge_point_comments (concept_id, age_band_id, degree_id, point_position, created_at DESC);

COMMENT ON TABLE knowledge_point_comments IS '知识点评论';

-- 知识点纠错
CREATE TABLE IF NOT EXISTS knowledge_point_corrections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  concept_id text NOT NULL,
  age_band_id text NOT NULL,
  degree_id text NOT NULL,
  point_position integer NOT NULL,
  device_id uuid NOT NULL REFERENCES devices (id) ON DELETE CASCADE,
  body text NOT NULL,
  suggested_text text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  reviewed_at timestamptz,
  reviewer_device_id uuid REFERENCES devices (id) ON DELETE SET NULL,
  points_awarded integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (concept_id, age_band_id, degree_id, point_position)
    REFERENCES knowledge_variant_points (concept_id, age_band_id, degree_id, position)
    ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS knowledge_point_corrections_status_idx
  ON knowledge_point_corrections (status, created_at DESC);
CREATE INDEX IF NOT EXISTS knowledge_point_corrections_target_idx
  ON knowledge_point_corrections (concept_id, age_band_id, degree_id, point_position, created_at DESC);

COMMENT ON TABLE knowledge_point_corrections IS '知识点纠错：审核通过后可发放积分';

-- 积分流水（审核通过等场景）
CREATE TABLE IF NOT EXISTS knowledge_point_credits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id uuid NOT NULL REFERENCES devices (id) ON DELETE CASCADE,
  correction_id uuid REFERENCES knowledge_point_corrections (id) ON DELETE SET NULL,
  amount integer NOT NULL,
  reason text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS knowledge_point_credits_device_idx
  ON knowledge_point_credits (device_id, created_at DESC);

COMMENT ON TABLE knowledge_point_credits IS '知识点相关积分流水（如纠错审核通过奖励）';
