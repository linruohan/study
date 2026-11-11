-- 素材表：图片、音频、视频的元数据，以及纯文本资源的正文。
--
-- 存储约定：
--   * text  ：正文放在 body，不落对象存储；
--   * 其他  ：文件本体放在 MinIO，这里只留 bucket + object_key。
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS assets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kind text NOT NULL,
  title text NOT NULL,
  mime_type text NOT NULL,
  -- 纯文本资源的内容；媒体资源为空。
  body text,
  -- 媒体资源在对象存储中的位置；文本资源为空。
  bucket text,
  object_key text,
  size_bytes bigint NOT NULL DEFAULT 0 CHECK (size_bytes >= 0),
  sha256 text CHECK (sha256 IS NULL OR length(sha256) = 64),
  -- 下面三列先留给后续的探测/转码任务，上传时可以为空。
  width integer CHECK (width IS NULL OR width > 0),
  height integer CHECK (height IS NULL OR height > 0),
  duration_ms integer CHECK (duration_ms IS NULL OR duration_ms >= 0),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT assets_kind_check
    CHECK (kind IN ('image', 'audio', 'video', 'text')),
  CONSTRAINT assets_storage_check CHECK (
    (kind = 'text' AND body IS NOT NULL AND object_key IS NULL AND bucket IS NULL)
    OR
    (kind <> 'text' AND body IS NULL AND object_key IS NOT NULL AND bucket IS NOT NULL)
  )
);

CREATE INDEX IF NOT EXISTS assets_created_idx ON assets (created_at DESC);
CREATE INDEX IF NOT EXISTS assets_kind_created_idx ON assets (kind, created_at DESC);
CREATE INDEX IF NOT EXISTS assets_metadata_gin_idx ON assets USING gin (metadata);
CREATE UNIQUE INDEX IF NOT EXISTS assets_object_key_uidx
  ON assets (bucket, object_key)
  WHERE object_key IS NOT NULL;

-- 更新时间由触发器维护，接口层不用每次手写 updated_at。
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS assets_set_updated_at ON assets;
CREATE TRIGGER assets_set_updated_at
  BEFORE UPDATE ON assets
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();
