-- 智者：用户贡献的知识与知识点。
--
-- 流程：任何人都能提交知识或知识点 → 服务端自动审批 → 通过即并入知识库
--       → 在知识库整包里带创建者名返回，知识库里能搜到这条知识和创建者。
--
-- 这里没有审批队列：提交即通过。保留状态列，
-- 以后要人工复核时把 pending 圈进 readKnowledgeBundle 就够了。

CREATE TABLE IF NOT EXISTS knowledge_sages (
  device_id uuid PRIMARY KEY REFERENCES devices (id) ON DELETE CASCADE,
  name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge_sages IS '智者：设备维度保存的创建者名字，一次填写处处显示';

CREATE TABLE IF NOT EXISTS knowledge_contributions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id uuid NOT NULL REFERENCES devices (id) ON DELETE CASCADE,
  kind text NOT NULL CHECK (kind IN ('knowledge', 'point')),
  -- 通过后写入的知识内容，入库前由接口校验。
  domain_id text REFERENCES knowledge_domains (id) ON DELETE SET NULL,
  age_band_id text REFERENCES knowledge_age_bands (id) ON DELETE SET NULL,
  degree_id text REFERENCES knowledge_degrees (id) ON DELETE SET NULL,
  concept_id text REFERENCES knowledge_concepts (id) ON DELETE SET NULL,
  position integer CHECK (position IS NULL OR position >= 1),
  topic text NOT NULL,
  doing text,
  note text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved')),
  reviewed_at timestamptz,
  applied_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge_contributions IS '知识贡献：提交即审批，通过后并入知识库并保留创建者';

CREATE INDEX IF NOT EXISTS knowledge_contributions_device_idx
  ON knowledge_contributions (device_id, created_at DESC);

CREATE INDEX IF NOT EXISTS knowledge_contributions_concept_idx
  ON knowledge_contributions (concept_id)
  WHERE concept_id IS NOT NULL;

-- 通过时才允许带概念引用：知识点必须挂在已有概念上。
-- knowledge 类型不需要 position（它是新建知识，不是追加知识点）。
ALTER TABLE knowledge_contributions
  ADD CONSTRAINT knowledge_contributions_applied_check CHECK (
    status = 'pending'
    OR (
      status = 'approved'
      AND concept_id IS NOT NULL
      AND (kind = 'knowledge' OR (kind = 'point' AND position IS NOT NULL))
    )
  );
