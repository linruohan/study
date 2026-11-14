class LearningRecord {
  const LearningRecord({
    required this.id,
    required this.at,
    required this.source,
    required this.subject,
    required this.body,
    this.conceptId,
    this.categoryId,
    this.ageBandId,
  });

  final String id;
  final DateTime at;
  final String source;
  final String subject;
  final String body;

  /// 这一步对应的概念 id；旧档案没有这一项，读回时为 null。
  final String? conceptId;

  /// 这一步所属分类 id，用于按分类回看。
  final String? categoryId;

  /// 这一步是在哪个年龄档做的，便于换档后仍能追溯。
  final String? ageBandId;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'at': at.toIso8601String(),
      'source': source,
      'subject': subject,
      'body': body,
      if (conceptId != null) 'conceptId': conceptId,
      if (categoryId != null) 'categoryId': categoryId,
      if (ageBandId != null) 'ageBandId': ageBandId,
    };
  }

  static LearningRecord fromJson(Map<String, Object?> json) {
    return LearningRecord(
      id: json['id']! as String,
      at: DateTime.parse(json['at']! as String),
      source: json['source']! as String,
      subject: json['subject']! as String,
      body: json['body']! as String,
      conceptId: json['conceptId'] as String?,
      // 旧数据里的键叫 domainId。
      categoryId: (json['categoryId'] ?? json['domainId']) as String?,
      ageBandId: json['ageBandId'] as String?,
    );
  }
}
