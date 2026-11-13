/// 智者模块的接口结构：字段名用驼峰，客户端可直接映射成模型。

/// 提交知识（kind = knowledge）或知识点（kind = point）。
export interface ContributionInput {
  kind: 'knowledge' | 'point';
  domainId: string;
  ageBandId: string;
  degreeId: string;
  conceptId?: string | null;
  position?: number | null;
  topic: string;
  doing?: string | null;
  note?: string | null;
}

export interface ContributionDto {
  id: string;
  kind: 'knowledge' | 'point';
  domainId: string | null;
  ageBandId: string | null;
  degreeId: string | null;
  conceptId: string | null;
  position: number | null;
  topic: string;
  doing: string | null;
  note: string | null;
  status: 'pending' | 'approved';
  reviewedAt: string | null;
  createdAt: string;
}

/// 知识库整包里的创建者：概念 id 或概念 id+程度 id → 智者名。
export interface SageCredits {
  knowledge: Record<string, string>;
  points: Record<string, string>;
}
