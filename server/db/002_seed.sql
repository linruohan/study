-- 两条示例文本资源：用来确认「文本进库、媒体进对象存储」这条路通。
WITH seed(id, title, body) AS (
  VALUES
    (
      '00000000-0000-4000-8000-000000000001'::uuid,
      '示例 · 素材库怎么用',
      E'# 素材库怎么用\n\n这个库只做两件事：\n\n1. 记下图片、音频、视频在哪里（MinIO 的 object_key）。\n2. 存下纯文本内容本身。\n\n读的时候统一走 `/api/assets`，不用关心底层是对象存储还是数据库。'
    ),
    (
      '00000000-0000-4000-8000-000000000002'::uuid,
      '示例 · 上传约定',
      E'图片、音频、视频用 multipart 上传，字段名 `file`；\n纯文本用 JSON 提交到 `/api/assets/text`。\n单个文件默认不超过 50 MB。'
    )
)
INSERT INTO assets (id, kind, title, mime_type, body, size_bytes, sha256, metadata)
SELECT
  id,
  'text',
  title,
  'text/markdown',
  body,
  octet_length(body),
  encode(digest(body, 'sha256'), 'hex'),
  '{"source": "seed"}'::jsonb
FROM seed
ON CONFLICT (id) DO NOTHING;
