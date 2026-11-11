import 'age_band.dart';
import 'catalog/language.dart';
import 'catalog/life.dart';
import 'catalog/math.dart';
import 'concept.dart';
import 'domain.dart';
import 'taxonomy.dart';

/// 本机知识图谱：替代服务端的图谱中台，只保存这一台设备够用的关系与查询。
///
/// 服务端的 Neo4j、消息队列不引入。等以后需要多端同步时，
/// 只要让远端实现同样这几个查询，界面和路径算法不用改。
class KnowledgeGraph {
  const KnowledgeGraph({required this.domains});

  /// 默认接入的领域。新增领域只加一个 catalog 文件并登记在这里。
  static const defaults = KnowledgeGraph(
    domains: [languageDomain, mathDomain, lifeDomain],
  );

  /// 已接入的领域，顺序就是引导路径的默认优先顺序。
  final List<LearningDomain> domains;

  /// 本档有内容的领域。
  List<LearningDomain> domainsFor(AgeBand band) {
    return domains.where((domain) => domain.hasContent(band)).toList();
  }

  /// 九类分类在本档的视图：有内容的领域挂在各自的类别下。
  ///
  /// 类别顺序固定为九类的注册顺序；没有内容的类别仍然出现，
  /// 让树的形状稳定，界面上给「还没有知识」的空态。
  List<({ScholarCategory category, List<LearningDomain> domains})>
      categoriesFor(AgeBand band) {
    final grouped = <ScholarCategory, List<LearningDomain>>{};
    for (final domain in domainsFor(band)) {
      grouped.putIfAbsent(domain.category, () => []).add(domain);
    }
    return [
      for (final category in nineCategories)
        (
          category: category,
          domains: grouped[category] ?? const [],
        ),
    ];
  }

  /// 某一类别下本档有内容的领域。
  List<LearningDomain> domainsInCategory(
    ScholarCategory category,
    AgeBand band,
  ) {
    return domainsFor(band)
        .where((domain) => domain.category.id == category.id)
        .toList();
  }

  /// 按 id 找领域，找不到返回 null。
  LearningDomain? domainById(String id) {
    for (final domain in domains) {
      if (domain.id == id) {
        return domain;
      }
    }
    return null;
  }

  /// 按 id 找概念，找不到返回 null。
  Concept? conceptById(String id) {
    for (final domain in domains) {
      for (final concept in domain.concepts) {
        if (concept.id == id) {
          return concept;
        }
      }
    }
    return null;
  }

  /// 前置概念是否都已到达熟练。没有前置的概念直接解锁。
  ///
  /// 前置如果不在当前年龄档，说明它在更早的目录里，本档不重复阻挡。
  bool unlocked(Concept concept, Set<String> ready, AgeBand band) {
    for (final id in concept.prerequisites) {
      final prerequisite = conceptById(id);
      if (prerequisite == null || !prerequisite.availableIn(band)) {
        continue;
      }
      if (!ready.contains(id)) {
        return false;
      }
    }
    return true;
  }

  /// 今日下一步：关注领域优先，其次按领域注册顺序和深浅。
  ///
  /// 已经到达熟练的不再占今日任务；没解锁的等前置。
  /// 全部走完返回 null。
  Concept? nextStep(
    AgeBand band,
    Set<String> ready, {
    String? focusDomainId,
  }) {
    final candidates = <({int rank, int domainOrder, Concept concept})>[];
    for (var order = 0; order < domains.length; order++) {
      final domain = domains[order];
      for (final concept in domain.conceptsFor(band)) {
        if (ready.contains(concept.id) || !unlocked(concept, ready, band)) {
          continue;
        }
        candidates.add((
          rank: domain.id == focusDomainId ? 0 : 1,
          domainOrder: order,
          concept: concept,
        ));
      }
    }
    if (candidates.isEmpty) {
      return null;
    }
    candidates.sort((a, b) {
      final byRank = a.rank.compareTo(b.rank);
      if (byRank != 0) {
        return byRank;
      }
      // 深浅优先于领域顺序：今日先补最浅的一格，不按学科轮流。
      final byDepth = a.concept.depth.compareTo(b.concept.depth);
      if (byDepth != 0) {
        return byDepth;
      }
      final byDomain = a.domainOrder.compareTo(b.domainOrder);
      if (byDomain != 0) {
        return byDomain;
      }
      return a.concept.id.compareTo(b.concept.id);
    });
    return candidates.first.concept;
  }

  /// 某领域在本档已到达熟练或掌握的概念数，用来显示进度。
  int readyCount(LearningDomain domain, AgeBand band, Set<String> ready) {
    return domain.conceptsFor(band).where((concept) => ready.contains(concept.id)).length;
  }
}
