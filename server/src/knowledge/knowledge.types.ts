/// 知识库接口的返回结构：字段名用驼峰，客户端可直接映射成模型。
export interface AgeBandDto {
  id: string;
  label: string;
  shortLabel: string;
  howToLearn: string;
  showsSubjectNames: boolean;
}

export interface DegreeDto {
  id: string;
  label: string;
}

export interface CategoryDto {
  id: string;
  /// 父分类 id；为空表示九大基类，非空表示子类型（可嵌套）。
  parentId?: string | null;
  name: string;
  question: string;
  ancient: string;
  modern: string;
  glyph: string;
  color: string;
}

/// 知识点下的章节：最基础的知识单元。
export interface ChapterDto {
  title: string;
  content?: string | null;
}

export interface VariantDto {
  topic: string;
  glyph: string | null;
  doing: string;
  praise: string;
  check: string;
  answer: string;
  note: string | null;
  /// 学习程度 id -> 该程度下的知识点，按顺序排列。
  points: Record<string, string[]>;
  /// 学习程度 id -> pointPosition(1-based) -> 章节列表（可选扩展）。
  chapters?: Record<string, Record<string, ChapterDto[]>>;
}

export interface ConceptDto {
  id: string;
  depth: number;
  prerequisites: string[];
  /// 年龄段 id → 该档的呈现。
  variants: Record<string, VariantDto>;
}

export interface DomainDto {
  id: string;
  name: string;
  glyph: string;
  color: string;
  categoryId: string;
  concepts: ConceptDto[];
}

/// 知识库整包里的创建者：概念 id / 知识点键 → 智者名。
export interface SageCredits {
  knowledge: Record<string, string>;
  points: Record<string, string>;
}

export interface KnowledgeBundle {
  ageBands: AgeBandDto[];
  degrees: DegreeDto[];
  categories: CategoryDto[];
  domains: DomainDto[];
  /// 通过审批的贡献对应的创建者名；空对象表示还没有贡献。
  sageCredits?: SageCredits;
}
