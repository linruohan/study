import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/archive/archive_file.dart';
import 'package:study_app/archive/learning_record.dart';

import 'support/study_fixture.dart';

void main() {
  test('一条练习可以写入档案再读出', () {
    final record = LearningRecord(
      id: '1',
      at: DateTime.utc(2026, 10, 17),
      source: '应用内练习',
      subject: '语',
      body: '指出太阳是「日」',
    );
    final read = ArchiveFile.parse(ArchiveFile(records: [record]).toJsonString());
    expect(read.records.single.body, record.body);
    expect(read.records.single.subject, '语');
    expect(read.records.single.source, '应用内练习');
  });

  test('练习写入仓库，再导出一份副本', () async {
    final study = await TestStudy.create();
    addTearDown(study.dispose);

    final saved = await study.archiveStore.addPractice(
      subject: '语',
      body: '指出太阳是「日」',
      at: DateTime.utc(2026, 10, 17, 1, 2, 3),
    );
    expect(saved.records, hasLength(1));

    final loaded = await study.archiveStore.load();
    expect(loaded.records.single.body, '指出太阳是「日」');
    // 保存时已同步到数据仓库。
    expect(study.api.saveCount, 1);

    final copy = await study.archiveStore.exportCopy();
    expect(copy.existsSync(), isTrue);
    expect(copy.path, contains('study_archive_'));
  });

  test('监护人观察和练习写在同一份档案里', () async {
    final study = await TestStudy.create();
    addTearDown(study.dispose);

    await study.archiveStore.addPractice(subject: '语', body: '指出太阳是「日」');
    final saved = await study.archiveStore.addObservation(body: '对声音有反应');

    expect(saved.records, hasLength(2));
    expect(saved.records.last.source, '监护人观察');
    expect(saved.records.last.subject, '照护');
    expect(saved.records.last.body, '对声音有反应');
  });

  test('带概念 id 的练习可以写入再读出', () async {
    final study = await TestStudy.create();
    addTearDown(study.dispose);

    await study.archiveStore.addPractice(
      subject: '语',
      body: '指出太阳是「日」',
      conceptId: 'zi_ri',
      domainId: 'language',
      ageBandId: 'toddler',
    );
    final loaded = await study.archiveStore.load();

    expect(loaded.records.single.conceptId, 'zi_ri');
    expect(loaded.records.single.domainId, 'language');
    expect(loaded.records.single.ageBandId, 'toddler');
  });
}
