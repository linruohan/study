/// 学习程度：一个知识按学到的深浅分成四档（入门/熟练/精通/创造）。
///
/// 名称来自数据库，客户端只保留 id 作为稳定标识。
class StudyDegree {
  const StudyDegree({required this.id, required this.label});

  /// 稳定标识，例如 beginner、familiar、advanced、creative。
  final String id;

  /// 显示名称，例如「入门」。
  final String label;

  /// 从知识库接口读取一档程度。
  factory StudyDegree.fromJson(Map<String, Object?> json) {
    return StudyDegree(
      id: json['id'] as String,
      label: json['label'] as String,
    );
  }
}
