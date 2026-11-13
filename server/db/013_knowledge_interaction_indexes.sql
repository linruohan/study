-- 知识点互动与层级查询优化索引（前向兼容，可重复执行）

-- 评论/纠错按设备查询与个人记录
CREATE INDEX IF NOT EXISTS knowledge_point_comments_device_idx
  ON knowledge_point_comments (device_id, created_at DESC);

CREATE INDEX IF NOT EXISTS knowledge_point_corrections_device_idx
  ON knowledge_point_corrections (device_id, created_at DESC);

-- 待审核纠错优先展示
CREATE INDEX IF NOT EXISTS knowledge_point_corrections_pending_idx
  ON knowledge_point_corrections (created_at DESC)
  WHERE status = 'pending';

-- 积分流水按纠错追溯
CREATE INDEX IF NOT EXISTS knowledge_point_credits_correction_idx
  ON knowledge_point_credits (correction_id);

-- 章节按知识点批量读取已有主键/排序，可补充内容检索预留（当前仅保障查询计划稳定）
COMMENT ON COLUMN knowledge_variant_point_chapters.chapter_position IS '章节序号（同一知识点内从 1 开始，按序展示）';
