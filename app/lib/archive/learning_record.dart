class LearningRecord {
  const LearningRecord({
    required this.id,
    required this.at,
    required this.source,
    required this.subject,
    required this.body,
  });

  final String id;
  final DateTime at;
  final String source;
  final String subject;
  final String body;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'at': at.toIso8601String(),
      'source': source,
      'subject': subject,
      'body': body,
    };
  }

  static LearningRecord fromJson(Map<String, Object?> json) {
    return LearningRecord(
      id: json['id']! as String,
      at: DateTime.parse(json['at']! as String),
      source: json['source']! as String,
      subject: json['subject']! as String,
      body: json['body']! as String,
    );
  }
}
