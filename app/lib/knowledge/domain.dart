import 'package:flutter/material.dart';

import 'age_band.dart';
import 'concept.dart';

/// 学习领域：一组按深浅排序的概念，相当于文档里的「领域适配器」。
///
/// 新增领域只要加一个数据文件并注册进 [KnowledgeGraph]，
/// 不需要改界面和路径算法。
class LearningDomain {
  const LearningDomain({
    required this.id,
    required this.name,
    required this.glyph,
    required this.color,
    required this.concepts,
  });

  /// 稳定标识，写进本机档案。
  final String id;

  /// 显示名称，例如「语」「数」「生活与安全」。
  final String name;

  /// 没有大图时使用的符号，例如「字」。
  final String glyph;

  /// 低饱和的领域色，用于卡片和大图，不做高对比霓虹色。
  final Color color;

  /// 本领域的全部概念，允许跨多个年龄档。
  final List<Concept> concepts;

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
}
