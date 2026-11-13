-- 用户数据：按设备区分设置、计划和学习记录。
--
-- 应用只保留界面与设备 ID，业务数据全部落库。
-- 设备 ID 由客户端生成（UUID），首次写入时自动登记。

CREATE TABLE IF NOT EXISTS devices (
  id uuid PRIMARY KEY,
  created_at timestamptz NOT NULL DEFAULT now(),
  last_seen_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE devices IS '客户端设备：UUID 由应用生成，用于区分不同设备的用户数据';

CREATE TABLE IF NOT EXISTS study_profiles (
  device_id uuid PRIMARY KEY REFERENCES devices (id) ON DELETE CASCADE,
  -- 还没选年龄档时为空。
  age_band_id text REFERENCES knowledge_age_bands (id),
  focus_domain_id text REFERENCES knowledge_domains (id) ON DELETE SET NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE study_profiles IS '学习设置：当前年龄档与关注领域';

CREATE TABLE IF NOT EXISTS study_plans (
  device_id uuid NOT NULL REFERENCES devices (id) ON DELETE CASCADE,
  -- 客户端生成的计划 id，仅在同一设备内唯一。
  id text NOT NULL,
  domain_id text NOT NULL REFERENCES knowledge_domains (id) ON DELETE CASCADE,
  depth text NOT NULL CHECK (depth IN ('brief', 'deep')),
  concept_id text REFERENCES knowledge_concepts (id) ON DELETE CASCADE,
  degree_id text REFERENCES knowledge_degrees (id),
  start_at timestamptz NOT NULL,
  remind boolean NOT NULL DEFAULT true,
  done boolean NOT NULL DEFAULT false,
  reminded_at timestamptz,
  snoozed_until timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (device_id, id)
);

COMMENT ON TABLE study_plans IS '学习计划：领域级与知识级计划共用一张表';

CREATE INDEX IF NOT EXISTS study_plans_device_start_idx
  ON study_plans (device_id, start_at);

CREATE TABLE IF NOT EXISTS learning_records (
  device_id uuid NOT NULL REFERENCES devices (id) ON DELETE CASCADE,
  -- 客户端生成的记录 id，仅在同一设备内唯一。
  id text NOT NULL,
  at timestamptz NOT NULL,
  source text NOT NULL,
  subject text NOT NULL,
  body text NOT NULL,
  -- 旧记录可能没有概念、领域或年龄档，允许为空。
  concept_id text REFERENCES knowledge_concepts (id) ON DELETE SET NULL,
  domain_id text REFERENCES knowledge_domains (id) ON DELETE SET NULL,
  age_band_id text REFERENCES knowledge_age_bands (id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (device_id, id)
);

COMMENT ON TABLE learning_records IS '学习档案：练习、监护人观察和小测记录';

CREATE INDEX IF NOT EXISTS learning_records_device_at_idx
  ON learning_records (device_id, at DESC);

DROP TRIGGER IF EXISTS study_profiles_set_updated_at ON study_profiles;
CREATE TRIGGER study_profiles_set_updated_at
  BEFORE UPDATE ON study_profiles
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS study_plans_set_updated_at ON study_plans;
CREATE TRIGGER study_plans_set_updated_at
  BEFORE UPDATE ON study_plans
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();
