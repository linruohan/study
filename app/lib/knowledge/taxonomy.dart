import 'package:flutter/material.dart';

import 'hex_color.dart';

/// 九类分类法：以「人」为圆心的知识分类。
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
  });

  /// 稳定 id，被领域引用。
  final String id;

  /// 父分类 id；为空表示九大基类，非空表示子类型（可嵌套）。
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

  /// 从知识库接口读取一类。
  factory ScholarCategory.fromJson(Map<String, Object?> json) {
    return ScholarCategory(
      id: json['id'] as String,
      parentId: json['parentId'] as String?,
      name: json['name'] as String,
      question: json['question'] as String,
      ancient: json['ancient'] as String,
      modern: json['modern'] as String,
      glyph: json['glyph'] as String,
      color: colorFromHex(json['color'] as String?),
    );
  }
}
