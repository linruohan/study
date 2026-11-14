import 'age_band.dart';
import 'concept.dart';
import 'taxonomy.dart';

/// 知识图谱：把数据库返回的分类树（父类/子类）包成界面需要的查询。
///
/// 客户端只保留查询逻辑，不再内置任何分类数据。
class KnowledgeGraph {
  KnowledgeGraph({required this.categories});

  /// 分类树（父类/子类，可嵌套），知识直接挂在分类上；顶级顺序来自数据库。
  final List<ScholarCategory> categories;

  /// 本档有内容的分类。
  List<ScholarCategory> categoriesWithContent(AgeBand band) {
    return categories.where((category) => category.hasContent(band)).toList();
  }

  /// 顶级分类（无父级）。
  List<ScholarCategory> get rootCategories =>
      categories.where((c) => c.parentId == null).toList();

  /// 某分类的直接子类。
  List<ScholarCategory> childrenOf(String categoryId) =>
      categories.where((c) => c.parentId == categoryId).toList();

  /// 某分类及其所有后代子类。
  ///
  /// 新建知识时用来就近选择分类，空子类也能落进去。
  List<ScholarCategory> categoriesUnder(ScholarCategory category) {
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
    return categories.where((c) => ids.contains(c.id)).toList();
  }

  /// 按 id 找分类，找不到返回 null。
  ScholarCategory? categoryById(String id) {
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  /// 按 id 找概念，找不到返回 null。
  Concept? conceptById(String id) {
    for (final category in categories) {
      for (final concept in category.concepts) {
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

  /// 今日下一步：关注分类优先，其次按分类顺序和深浅。
  Concept? nextStep(
    AgeBand band,
    Set<String> ready, {
    String? focusCategoryId,
  }) {
    final candidates =
        <({int rank, int categoryOrder, Concept concept})>[];
    for (var order = 0; order < categories.length; order++) {
      final category = categories[order];
      for (final concept in category.conceptsFor(band)) {
        if (ready.contains(concept.id) || !unlocked(concept, ready, band)) {
          continue;
        }
        candidates.add((
          rank: category.id == focusCategoryId ? 0 : 1,
          categoryOrder: order,
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
      final byCategory = a.categoryOrder.compareTo(b.categoryOrder);
      if (byCategory != 0) {
        return byCategory;
      }
      return a.concept.id.compareTo(b.concept.id);
    });
    return candidates.first.concept;
  }

  /// 某分类在本档已到达熟练或掌握的知识数，用来显示进度。
  int readyCount(
    ScholarCategory category,
    AgeBand band,
    Set<String> ready,
  ) {
    return category.conceptsFor(band)
        .where((concept) => ready.contains(concept.id))
        .length;
  }
}
