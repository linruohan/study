import 'package:flutter/material.dart';

/// 九类分类法：以「人」为圆心的知识分类。
///
/// 知识的分类本质上是「人如何与世界打交道」的分类——
/// 人对自然、对他人、对自己、对超越者的认知与实践。
/// 新增的领域都按这九类归类，不再另起一套学科清单。
class ScholarCategory {
  const ScholarCategory({
    required this.id,
    required this.name,
    required this.question,
    required this.ancient,
    required this.modern,
    required this.glyph,
    required this.color,
  });

  /// 稳定 id，被领域引用。
  final String id;

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

  /// 由 id 找回类别；未知 id 返回 null。
  static ScholarCategory? fromId(String? id) {
    if (id == null) {
      return null;
    }
    for (final category in nineCategories) {
      if (category.id == id) {
        return category;
      }
    }
    return null;
  }
}

/// 九类，顺序固定；知识库树和计划分组都按这个顺序。
const nineCategories = <ScholarCategory>[
  ScholarCategory(
    id: 'education',
    name: '教养之学',
    question: '人如何成为有文化、有价值根基的人',
    ancient: '六艺略',
    modern: '哲学、历史学、语言学、教育学',
    glyph: '教',
    color: Color(0xFF8C4A2F),
  ),
  ScholarCategory(
    id: 'thought',
    name: '思辨之学',
    question: '人如何理解社会、秩序与观念',
    ancient: '诸子略',
    modern: '政治学、经济学、法学、社会学、伦理学',
    glyph: '思',
    color: Color(0xFF7A6A54),
  ),
  ScholarCategory(
    id: 'expression',
    name: '表达之学',
    question: '人如何抒发情感、创造审美',
    ancient: '诗赋略',
    modern: '文学、艺术学、音乐学、戏剧影视学',
    glyph: '诗',
    color: Color(0xFF9C5B6E),
  ),
  ScholarCategory(
    id: 'strategy',
    name: '对抗之学',
    question: '人如何应对冲突、竞争与组织博弈',
    ancient: '兵书略',
    modern: '军事学、国际关系、博弈论',
    glyph: '弈',
    color: Color(0xFF5B5E6E),
  ),
  ScholarCategory(
    id: 'cosmos',
    name: '天地之学',
    question: '人如何认识与推算自然时空秩序',
    ancient: '数术略',
    modern: '数学、天文学、物理学、化学、数据科学',
    glyph: '天',
    color: Color(0xFF3E6F8C),
  ),
  ScholarCategory(
    id: 'life',
    name: '生命之学',
    question: '人如何维护身体、健康与生命',
    ancient: '方技略',
    modern: '医学、药学、公共卫生、体育学',
    glyph: '生',
    color: Color(0xFF6F7A63),
  ),
  ScholarCategory(
    id: 'making',
    name: '制作之学',
    question: '人如何改造世界、制造器物与系统',
    ancient: '散见于方技、兵书',
    modern: '工学、农学、建筑学、材料科学',
    glyph: '工',
    color: Color(0xFF4E7A78),
  ),
  ScholarCategory(
    id: 'governance',
    name: '群治之学',
    question: '人如何组织大规模社会、分配资源与权力',
    ancient: '诸子、史部',
    modern: '管理学、公共管理、制度法学',
    glyph: '群',
    color: Color(0xFF837565),
  ),
  ScholarCategory(
    id: 'self',
    name: '自知之学',
    question: '人如何认识自己——心智、行为与意义',
    ancient: '散见于诸子、方技',
    modern: '心理学、认知科学、人类学',
    glyph: '己',
    color: Color(0xFF6A5A82),
  ),
];
