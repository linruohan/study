import 'package:flutter/material.dart';

import 'age_band.dart';
import 'concept.dart';
import 'hex_color.dart';

/// 知识分类树：以「人」为圆心的父类/子类层级，知识直接挂在分类上。
///
/// 分类内容全部来自数据库，客户端只保留这个数据形态。
class ScholarCategory {
  const ScholarCategory({
    required this.id,
    required this.name,
    required this.question,
    required this.ancient,
    required this.modern,
    required this.glyph,
    required this.color,
    this.parentId,
    this.concepts = const [],
  });

  /// 稳定 id，被知识与计划引用。
  final String id;

  /// 父分类 id；为空表示顶级分类，非空表示子类（可嵌套）。
  final String? parentId;

  /// 类别名称，例如「教养之学」。
  final String name;

  /// 回答「人」的什么问题。
  final String question;

  /// 古代对应，例如「六艺略」。
  final String ancient;

  /// 现代主要学科。
  final String modern;

  /// 没有大图时使用的符号，例如「教」。
  final String glyph;

  /// 低饱和的类别色。
  final Color color;

  /// 直接挂在这个分类下的知识，从浅到深。
  final List<Concept> concepts;

  /// 从知识库接口读取一类及其直属知识。
  factory ScholarCategory.fromJson(
    Map<String, Object?> json, {
    required Map<String, AgeBand> ageBands,
  }) {
    final concepts = <Concept>[];
    final rawConcepts = json['concepts'];
    if (rawConcepts is List) {
      final categoryId = json['id'] as String;
      for (final item in rawConcepts) {
        if (item is Map) {
          concepts.add(
            Concept.fromJson(
              Map<String, Object?>.from(item),
              categoryId: categoryId,
              ageBands: ageBands,
            ),
          );
        }
      }
    }
    return ScholarCategory(
      id: json['id'] as String,
      parentId: json['parentId'] as String?,
      name: json['name'] as String,
      question: json['question'] as String,
      ancient: json['ancient'] as String,
      modern: json['modern'] as String,
      glyph: json['glyph'] as String,
      color: colorFromHex(json['color'] as String?),
      concepts: concepts,
    );
  }

  /// 本档可见的知识，从浅到深排序；同一层按 id 稳定排序。
  List<Concept> conceptsFor(AgeBand band) {
    final list =
        concepts.where((concept) => concept.availableIn(band)).toList();
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
        // 种子里的「生活与安全」领域与根分类 life 撞名，迁移后带 cat_ 前缀。
        case 'cat_life':
          return '识物';
      }
    }
    return name;
  }
}
