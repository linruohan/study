/// 知识库里的创建者归属：概念 id 或 知识点键 → 智者名。
///
/// 接口字段：
/// - knowledge: 概念 id → 创建这条知识的智者名
/// - points: 'concept_id:age_band_id:degree_id:position' → 提交这条知识点的智者名
class SageCredits {
  const SageCredits({
    required this.knowledge,
    required this.points,
  });

  /// 概念 id → 智者名；通过审批后，查询知识时就能看到谁创建的。
  final Map<String, String> knowledge;

  /// 知识点键 → 智者名；查询知识点详情时显示谁补充的。
  final Map<String, String> points;

  factory SageCredits.fromJson(Map<String, Object?>? json) {
    if (json == null) {
      return const SageCredits(knowledge: {}, points: {});
    }
    return SageCredits(
      knowledge: _asStringMap(json['knowledge']),
      points: _asStringMap(json['points']),
    );
  }

  static Map<String, String> _asStringMap(Object? raw) {
    final result = <String, String>{};
    if (raw is! Map) {
      return result;
    }
    for (final entry in raw.entries) {
      if (entry.value is String) {
        result[entry.key.toString()] = entry.value as String;
      }
    }
    return result;
  }

  /// 某个知识概念的创建者；没有归属时返回空字符串。
  String creatorOfConcept(String conceptId) => knowledge[conceptId] ?? '';

  /// 某条知识点的创建者；key 为 'concept_id:age_band_id:degree_id:position'。
  String creatorOfPoint(String key) => points[key] ?? '';
}
