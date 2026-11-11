/// 素材种类：文本直接进库，其余三种放对象存储。
export type AssetKind = 'image' | 'audio' | 'video' | 'text';

/// 一条素材的完整记录，字段与 assets 表一一对应。
export interface AssetRecord {
  id: string;
  kind: AssetKind;
  title: string;
  mimeType: string;
  body: string | null;
  bucket: string | null;
  objectKey: string | null;
  sizeBytes: number;
  sha256: string | null;
  width: number | null;
  height: number | null;
  durationMs: number | null;
  metadata: Record<string, unknown>;
  createdAt: Date;
  updatedAt: Date;
}

/// 新建素材时需要的字段。
export interface NewAsset {
  id: string;
  kind: AssetKind;
  title: string;
  mimeType: string;
  body?: string | null;
  bucket?: string | null;
  objectKey?: string | null;
  sizeBytes: number;
  sha256?: string | null;
  metadata?: Record<string, unknown>;
}
