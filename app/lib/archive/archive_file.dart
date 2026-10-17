import 'dart:convert';

import 'learning_record.dart';

class ArchiveFile {
  const ArchiveFile({required this.records});

  static const version = 1;

  final List<LearningRecord> records;

  ArchiveFile add(LearningRecord record) {
    return ArchiveFile(records: [...records, record]);
  }

  String toJsonString() {
    final payload = {
      'version': version,
      'records': records.map((record) => record.toJson()).toList(),
    };
    return jsonEncode(payload);
  }

  static ArchiveFile parse(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('档案不是对象');
    }
    final map = Map<String, Object?>.from(decoded);
    final version = map['version'];
    if (version != ArchiveFile.version) {
      throw FormatException('不认识的档案版本：$version');
    }
    final list = map['records'];
    if (list is! List) {
      throw const FormatException('档案缺少记录列表');
    }
    return ArchiveFile(
      records: [
        for (final item in list)
          LearningRecord.fromJson(Map<String, Object?>.from(item as Map)),
      ],
    );
  }
}
