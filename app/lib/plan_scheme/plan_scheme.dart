/// 学习计划方案：蒙学、小学一年级……大一等为系统内置默认方案，
/// 用户也可以创建自己的方案。与服务端 plan_schemes 三张表对应。
///
/// 方案按「维度（领域）→ 知识内容 → 学习程度」组织；
/// 条目可关联一条知识概念（conceptId），没有就为空。
library;

/// 方案维度（领域），如「语言与识字」「语文」。
class PlanSchemeDimension {
  const PlanSchemeDimension({
    required this.id,
    required this.name,
    required this.sortOrder,
    this.items = const [],
  });

  final String id;
  final String name;
  final int sortOrder;
  final List<PlanSchemeItem> items;

  factory PlanSchemeDimension.fromJson(Map<String, dynamic> json) {
    return PlanSchemeDimension(
      id: json['id'] as String,
      name: json['name'] as String,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      items: [
        for (final item in (json['items'] as List? ?? const []))
          if (item is Map) PlanSchemeItem.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }

  Map<String, dynamic> toInputJson() => {
        'name': name,
        'items': [for (final item in items) item.toInputJson()],
      };
}

/// 方案维度条目：知识内容 + 学习程度，可选关联知识概念。
class PlanSchemeItem {
  const PlanSchemeItem({
    required this.id,
    required this.content,
    this.expectedLevel = '',
    this.conceptId,
    this.conceptTopic,
    this.sortOrder = 0,
  });

  final String id;
  final String content;
  final String expectedLevel;

  /// 关联的知识概念 id；未关联为 null。
  final String? conceptId;

  /// 关联概念的概要（呈现主题），列表页直接展示；未关联为 null。
  final String? conceptTopic;
  final int sortOrder;

  factory PlanSchemeItem.fromJson(Map<String, dynamic> json) {
    return PlanSchemeItem(
      id: json['id'] as String,
      content: json['content'] as String,
      expectedLevel: json['expectedLevel'] as String? ?? '',
      conceptId: json['conceptId'] as String?,
      conceptTopic: json['conceptTopic'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toInputJson() => {
        'content': content,
        'expectedLevel': expectedLevel,
        'conceptId': conceptId,
      };
}

/// 学习计划方案。
class PlanScheme {
  const PlanScheme({
    required this.id,
    required this.name,
    required this.stage,
    required this.stageSort,
    required this.sortOrder,
    this.description = '',
    this.isBuiltin = false,
    this.ownerUserId,
    this.dimensions = const [],
  });

  final String id;
  final String name;

  /// 阶段标识：mengxue/primary/junior/senior/college/graduate/master。
  final String stage;
  final int stageSort;
  final int sortOrder;
  final String description;

  /// true 表示系统内置方案；false 表示本人自建。
  final bool isBuiltin;
  final String? ownerUserId;
  final List<PlanSchemeDimension> dimensions;

  factory PlanScheme.fromJson(Map<String, dynamic> json) {
    return PlanScheme(
      id: json['id'] as String,
      name: json['name'] as String,
      stage: json['stage'] as String,
      stageSort: (json['stageSort'] as num?)?.toInt() ?? 0,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      description: json['description'] as String? ?? '',
      isBuiltin: json['isBuiltin'] as bool? ?? false,
      ownerUserId: json['ownerUserId'] as String?,
      dimensions: [
        for (final dim in (json['dimensions'] as List? ?? const []))
          if (dim is Map) PlanSchemeDimension.fromJson(Map<String, dynamic>.from(dim)),
      ],
    );
  }

  /// 容错解析：关键字段缺失/类型不对时返回 null，调用方跳过这条坏数据，
  /// 避免服务端一条脏记录让整页方案崩掉。
  static PlanScheme? tryFromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final stage = json['stage'];
    if (id is! String || id.isEmpty) return null;
    if (name is! String || name.isEmpty) return null;
    if (stage is! String || stage.isEmpty) return null;
    try {
      return PlanScheme.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toInputJson() => {
        'name': name,
        'stage': stage,
        'description': description,
        'dimensions': [for (final dim in dimensions) dim.toInputJson()],
      };
}

/// 阶段标识 → 显示名。
const Map<String, String> kPlanSchemeStageLabels = {
  'mengxue': '蒙学',
  'primary': '小学',
  'junior': '初中',
  'senior': '高中',
  'college': '大学',
  'graduate': '研究生',
  'master': '硕士',
};

/// 阶段标识 → 排序。
const Map<String, int> kPlanSchemeStageOrder = {
  'mengxue': 0,
  'primary': 1,
  'junior': 2,
  'senior': 3,
  'college': 4,
  'graduate': 5,
  'master': 6,
};
