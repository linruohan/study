import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/archive/learning_record.dart';
import 'package:study_app/guardian/care_guidance.dart';

void main() {
  LearningRecord record({
    required String source,
    required String body,
    required DateTime at,
  }) {
    return LearningRecord(
      id: at.microsecondsSinceEpoch.toString(),
      at: at,
      source: source,
      subject: source == '监护人观察' ? '照护' : '语',
      body: body,
    );
  }

  test('没有照护记录时说记录还不够，并用默认一步', () {
    final guidance = CareGuidance.fromRecords(const []);
    expect(guidance.basis, '记录还不够。');
    expect(guidance.what, contains('面对着孩子说话'));
    expect(guidance.reflection, contains('不编造特点'));
  });

  test('练习记录不算照护依据', () {
    final guidance = CareGuidance.fromRecords([
      record(
        source: '应用内练习',
        body: '指出太阳是「日」',
        at: DateTime.utc(2026, 10, 17),
      ),
    ]);
    expect(guidance.basis, '记录还不够。');
  });

  test('最近一条对声音有反应，只接着这一句，不作听力结论', () {
    final guidance = CareGuidance.fromRecords([
      record(
        source: '监护人观察',
        body: '睡眠比较规律',
        at: DateTime.utc(2026, 10, 16),
      ),
      record(
        source: '监护人观察',
        body: '对声音有反应',
        at: DateTime.utc(2026, 10, 17),
      ),
    ]);
    expect(guidance.basis, '依据是监护人观察「对声音有反应」。');
    expect(guidance.what, '建议：面对着孩子说话，等一下再继续。');
    expect(guidance.reflection, contains('不是听力结论'));
  });

  test('对不上的观察不解释', () {
    final guidance = CareGuidance.fromRecords([
      record(
        source: '监护人观察',
        body: '今天好像更聪明了',
        at: DateTime.utc(2026, 10, 17),
      ),
    ]);
    expect(guidance.basis, contains('不解释'));
    expect(guidance.reflection, '这不是原因判定。');
    expect(guidance.what, contains('面对着孩子说话'));
  });
}
