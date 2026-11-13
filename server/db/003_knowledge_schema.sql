-- 知识库结构：把客户端里的九类、领域、原子概念、分龄呈现和三档知识点落库。
--
-- 层级关系：
--   knowledge_categories（九类分类）
--     └ knowledge_domains（学习领域）
--         └ knowledge_concepts（原子概念）
--             ├ knowledge_concept_prerequisites（前置依赖）
--             └ knowledge_variants（同一概念在各年龄段的呈现）
--                 └ knowledge_variant_points（入门 / 熟悉 / 精通三档知识点）
--
-- 约定：
--   * 所有业务 id 沿用客户端里的稳定字符串，方便两边对照；
--   * 颜色存 #RRGGBB，不存 Flutter 的 ARGB 整数；
--   * 知识内容按目录顺序用 sort_order 排，避免依赖插入顺序。

CREATE TABLE IF NOT EXISTS knowledge_age_bands (
  id text PRIMARY KEY,
  label text NOT NULL,
  short_label text NOT NULL,
  how_to_learn text NOT NULL,
  -- 幼儿档不显示「语」「数」这类学科名，用于界面分支。
  shows_subject_names boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL
);

COMMENT ON TABLE knowledge_age_bands IS '年龄段字典：3–5 岁到离开学校以后的七档';

CREATE TABLE IF NOT EXISTS knowledge_degrees (
  id text PRIMARY KEY,
  label text NOT NULL,
  sort_order integer NOT NULL
);

COMMENT ON TABLE knowledge_degrees IS '学习程度字典：入门、熟悉、精通';

CREATE TABLE IF NOT EXISTS knowledge_categories (
  id text PRIMARY KEY,
  name text NOT NULL,
  question text NOT NULL,
  ancient text NOT NULL,
  modern text NOT NULL,
  glyph text NOT NULL,
  color text NOT NULL CHECK (color ~ '^#[0-9A-F]{6}$'),
  sort_order integer NOT NULL
);

COMMENT ON TABLE knowledge_categories IS '九类分类法：以人为圆心的知识分类';

CREATE TABLE IF NOT EXISTS knowledge_domains (
  id text PRIMARY KEY,
  name text NOT NULL,
  glyph text NOT NULL,
  color text NOT NULL CHECK (color ~ '^#[0-9A-F]{6}$'),
  category_id text NOT NULL REFERENCES knowledge_categories (id),
  sort_order integer NOT NULL
);

COMMENT ON TABLE knowledge_domains IS '学习领域：一组按深浅排序的原子概念';

CREATE INDEX IF NOT EXISTS knowledge_domains_category_idx
  ON knowledge_domains (category_id, sort_order);

CREATE TABLE IF NOT EXISTS knowledge_concepts (
  id text PRIMARY KEY,
  domain_id text NOT NULL REFERENCES knowledge_domains (id) ON DELETE CASCADE,
  -- 领域内的深浅层级，0 最浅。
  depth integer NOT NULL CHECK (depth >= 0),
  sort_order integer NOT NULL
);

COMMENT ON TABLE knowledge_concepts IS '原子概念：可学习的最小单元，同一概念跨年龄段只建一个节点';

CREATE INDEX IF NOT EXISTS knowledge_concepts_domain_idx
  ON knowledge_concepts (domain_id, depth, sort_order);

CREATE TABLE IF NOT EXISTS knowledge_concept_prerequisites (
  concept_id text NOT NULL REFERENCES knowledge_concepts (id) ON DELETE CASCADE,
  prerequisite_id text NOT NULL REFERENCES knowledge_concepts (id) ON DELETE CASCADE,
  PRIMARY KEY (concept_id, prerequisite_id),
  CONSTRAINT knowledge_prerequisites_not_self CHECK (concept_id <> prerequisite_id)
);

COMMENT ON TABLE knowledge_concept_prerequisites IS '概念的前置依赖：前置到达熟练后才解锁下一项';

CREATE TABLE IF NOT EXISTS knowledge_variants (
  concept_id text NOT NULL REFERENCES knowledge_concepts (id) ON DELETE CASCADE,
  age_band_id text NOT NULL REFERENCES knowledge_age_bands (id),
  topic text NOT NULL,
  glyph text,
  doing text NOT NULL,
  praise text NOT NULL,
  -- check 是 SQL 关键字，列名加 _question 后缀。
  check_question text NOT NULL,
  answer text NOT NULL,
  note text,
  PRIMARY KEY (concept_id, age_band_id)
);

COMMENT ON TABLE knowledge_variants IS '认知分级映射表：同一概念在各年龄档的呈现，没有写入的档就不出现';

CREATE INDEX IF NOT EXISTS knowledge_variants_age_band_idx
  ON knowledge_variants (age_band_id);

CREATE TABLE IF NOT EXISTS knowledge_variant_points (
  concept_id text NOT NULL,
  age_band_id text NOT NULL,
  degree_id text NOT NULL REFERENCES knowledge_degrees (id),
  -- 同一程度下知识点的先后顺序，从 1 开始。
  position integer NOT NULL CHECK (position >= 1),
  point text NOT NULL,
  PRIMARY KEY (concept_id, age_band_id, degree_id, position),
  FOREIGN KEY (concept_id, age_band_id)
    REFERENCES knowledge_variants (concept_id, age_band_id)
    ON DELETE CASCADE
);

COMMENT ON TABLE knowledge_variant_points IS '某一概念在某一年龄档下，入门/熟悉/精通各自的知识点';

CREATE INDEX IF NOT EXISTS knowledge_variant_points_degree_idx
  ON knowledge_variant_points (degree_id);
