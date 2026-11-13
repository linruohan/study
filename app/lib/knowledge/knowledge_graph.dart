import 'age_band.dart';
import 'concept.dart';
import 'domain.dart';
import 'taxonomy.dart';

/// 知识图谱：把数据库返回的领域与分类包成界面需要的查询。
///
/// 客户端只保留查询逻辑，不再内置任何领域或分类数据。
class KnowledgeGraph {
  KnowledgeGraph({required this.domains, required this.categories});

  /// 已接入的领域，顺序就是引导路径的默认优先顺序。
  final List<LearningDomain> domains;

  /// 九类分类，顺序来自数据库。
  final List<ScholarCategory> categories;

  /// 本档有内容的领域。
  List<LearningDomain> domainsFor(AgeBand band) {
    return domains.where((domain) => domain.hasContent(band)).toList();
  }

  /// 九大基类/根分类（无父级）。
  List<ScholarCategory> get rootCategories =>
      categories.where((c) => c.parentId == null).toList();

  /// 某分类的直接子类型。
  List<ScholarCategory> childrenOf(String categoryId) =>
      categories.where((c) => c.parentId == categoryId).toList();

  /// 某分类下直接挂载的、在本档可见的领域。
  List<LearningDomain> directDomainsInCategory(
    ScholarCategory category,
    AgeBand band,
  ) {
    return domainsFor(band)
        .where((domain) => domain.category.id == category.id)
        .toList();
  }

  /// 某一类别下挂载的全部领域（不看本档有没有内容）。
  ///
  /// 知识库树用这个来展示刚新建、还没添加知识的空领域。
  List<LearningDomain> allDomainsInCategory(ScholarCategory category) {
    return domains
        .where((domain) => domain.category.id == category.id)
        .toList();
  }

  /// 某分类及其所有后代子类型下挂载的领域。
  ///
  /// 新建知识时用来就近选择领域，空子类型也能落到父级的领域里。
  List<LearningDomain> domainsUnderCategory(ScholarCategory category) {
    final ids = <String>{};
    void walk(ScholarCategory current) {
      if (!ids.add(current.id)) {
        return;
      }
      for (final child in childrenOf(current.id)) {
        walk(child);
      }
    }

    walk(category);
    return domains.where((domain) => ids.contains(domain.category.id)).toList();
  }

  /// 九类分类在本档的视图（兼容旧接口）：包含所有分类及其直接领域。
  List<({ScholarCategory category, List<LearningDomain> domains})>
      categoriesFor(AgeBand band) {
    return [
      for (final category in categories)
        (
          category: category,
          domains: directDomainsInCategory(category, band),
        ),
    ];
  }

  /// 某一类别下本档有内容的领域（含直接挂载）。
  List<LearningDomain> domainsInCategory(
    ScholarCategory category,
    AgeBand band,
  ) {
    return directDomainsInCategory(category, band);
  }

  /// 按 id 找分类。
  ScholarCategory? categoryById(String id) {
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
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

  /// 今日下一步：关注领域优先，其次按领域顺序和深浅。
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
    return domain.conceptsFor(band)
        .where((concept) => ready.contains(concept.id))
        .length;
  }
}
