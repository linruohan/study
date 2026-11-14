/// 学习计划方案的 DTO：方案、维度、条目。

/// 阶段标识：与内置方案阶段一致。
export type PlanSchemeStage =
  | 'mengxue'
  | 'primary'
  | 'junior'
  | 'senior'
  | 'college'
  | 'graduate'
  | 'master';

/// 方案维度条目：知识内容 + 学习程度，可选关联知识概念。
export interface PlanSchemeItemDto {
  id: string;
  content: string;
  expectedLevel: string;
  conceptId: string | null;
  /// 关联概念的概要（ topic ），便于列表页直接展示；未关联为 null。
  conceptTopic: string | null;
  sortOrder: number;
}

/// 方案维度（领域）。
export interface PlanSchemeDimensionDto {
  id: string;
  name: string;
  items: PlanSchemeItemDto[];
  sortOrder: number;
}

/// 学习计划方案。
export interface PlanSchemeDto {
  id: string;
  name: string;
  stage: PlanSchemeStage;
  stageSort: number;
  sortOrder: number;
  description: string;
  isBuiltin: boolean;
  ownerUserId: string | null;
  dimensions: PlanSchemeDimensionDto[];
}
