import 'package:flutter/material.dart';

import 'age_band.dart';
import 'concept.dart';
import 'hex_color.dart';
import 'taxonomy.dart';

/// 学习领域：一组按深浅排序的概念，相当于文档里的「领域适配器」。
///
/// 领域内容全部来自数据库，客户端不再内置任何领域数据。
class LearningDomain {
  LearningDomain({
    required this.id,
    required this.name,
    required this.glyph,
    required this.color,
    required this.concepts,
    required this.category,
  }) : categoryId = category.id;

  /// 稳定标识，写进档案和计划。
  final String id;

  /// 显示名称，例如「语」「数」「生活与安全」。
  final String name;

  /// 没有大图时使用的符号，例如「字」。
  final String glyph;

  /// 低饱和的领域色，用于卡片和大图。
  final Color color;

  /// 本领域的全部概念，允许跨多个年龄档。
  final List<Concept> concepts;

  /// 所属九类分类。
  final ScholarCategory category;

  /// 所属九类分类的 id，方便存档与比较。
  final String categoryId;

  /// 从知识库接口读取一个领域及其概念。
  factory LearningDomain.fromJson(
    Map<String, Object?> json, {
    required Map<String, AgeBand> ageBands,
    required List<ScholarCategory> categories,
  }) {
    final domainId = json['id'] as String;
    final categoryId = json['categoryId'] as String;
    final category = categories.firstWhere(
      (item) => item.id == categoryId,
      orElse: () => categories.first,
    );
    final rawConcepts = json['concepts'];
    final concepts = <Concept>[];
    if (rawConcepts is List) {
      for (final item in rawConcepts) {
        if (item is Map) {
          concepts.add(
            Concept.fromJson(
              Map<String, Object?>.from(item),
              domainId: domainId,
              ageBands: ageBands,
            ),
          );
        }
      }
    }
    return LearningDomain(
      id: domainId,
      name: json['name'] as String,
      glyph: json['glyph'] as String,
      color: colorFromHex(json['color'] as String?),
      concepts: concepts,
      category: category,
    );
  }

  /// 本档可见的概念，从浅到深排序；同一层按 id 稳定排序。
  List<Concept> conceptsFor(AgeBand band) {
    final list = concepts.where((concept) => concept.availableIn(band)).toList();
    list.sort((a, b) {
      final byDepth = a.depth.compareTo(b.depth);
      if (byDepth != 0) {
        return byDepth;
      }
      return a.id.compareTo(b.id);
    });
    return list;
  }

  /// 本档是否有内容可学。
  bool hasContent(AgeBand band) => conceptsFor(band).isNotEmpty;
  /// 当前年龄档下的显示名称。蒙学（幼儿）计划包含识文、识数、识物。
  String displayNameFor(AgeBand band) {
    if (band.id == 'toddler') {
      switch (id) {
        case 'language':
          return '识文';
        case 'math':
          return '识数';
        case 'life':
          return '识物';
      }
    }
    return name;
  }
}
