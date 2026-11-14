import 'age_band.dart';
import 'knowledge_graph.dart';
import 'sage_credit.dart';
import 'study_degree.dart';
import 'taxonomy.dart';

/// 知识库目录：一次加载后供全应用查询。
///
/// 所有内容来自服务端接口或本地缓存，客户端不再内置知识数据。
/// 目录由仓库持有并显式传递，不再有全局单例。
class KnowledgeCatalog {
  KnowledgeCatalog._({
    required this.ageBands,
    required this.degrees,
    required this.categories,
    required this.graph,
    required this.sageCredits,
  });

  final List<AgeBand> ageBands;
  final List<StudyDegree> degrees;
  final List<ScholarCategory> categories;
  final KnowledgeGraph graph;

  /// 通过审批的贡献对应的创建者名；空对象表示还没有贡献。
  final SageCredits sageCredits;

  /// 从接口 JSON 构建目录；字段缺失会抛错，由启动页展示加载失败。
  factory KnowledgeCatalog.fromJson(Map<String, Object?> json) {
    final ageBands = <AgeBand>[
      for (final item in _maps(json['ageBands']))
        AgeBand.fromJson(item),
    ];
    final degrees = <StudyDegree>[
      for (final item in _maps(json['degrees']))
        StudyDegree.fromJson(item),
    ];
    final bandById = {for (final band in ageBands) band.id: band};
    final categories = <ScholarCategory>[
      for (final item in _maps(json['categories']))
        ScholarCategory.fromJson(item, ageBands: bandById),
    ];
    if (ageBands.isEmpty || degrees.isEmpty || categories.isEmpty) {
      throw const FormatException('知识库缺少年龄段、程度或分类');
    }

    return KnowledgeCatalog._(
      ageBands: ageBands,
      degrees: degrees,
      categories: categories,
      graph: KnowledgeGraph(categories: categories),
      sageCredits: SageCredits.fromJson(
        json['sageCredits'] is Map
            ? Map<String, Object?>.from(json['sageCredits']! as Map)
            : null,
      ),
    );
  }

  /// 按 id 找年龄档。
  AgeBand? ageBandById(String? id) {
    if (id == null) {
      return null;
    }
    for (final band in ageBands) {
      if (band.id == id) {
        return band;
      }
    }
    return null;
  }

  /// 按 id 找学习程度。
  StudyDegree? degreeById(String? id) {
    if (id == null) {
      return null;
    }
    for (final degree in degrees) {
      if (degree.id == id) {
        return degree;
      }
    }
    return null;
  }

  /// 按 id 找九类分类。
  ScholarCategory? categoryById(String? id) {
    if (id == null) {
      return null;
    }
    for (final category in categories) {
      if (category.id == id) {
        return category;
      }
    }
    return null;
  }
}

/// 把接口里的数组安全地转成对象列表，坏项直接跳过。
List<Map<String, Object?>> _maps(Object? raw) {
  if (raw is! List) {
    return const [];
  }
  return [
    for (final item in raw)
      if (item is Map) Map<String, Object?>.from(item),
  ];
}
