import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/archive/archive_file.dart';
import 'package:study_app/archive/learning_record.dart';
import 'package:study_app/archive/local_archive.dart';
import 'package:study_app/knowledge/age_band.dart';
import 'package:study_app/knowledge/knowledge_graph.dart';
import 'package:study_app/learning/ladder.dart';
import 'package:study_app/learning/learner_state.dart';
import 'package:study_app/learning/mastery.dart';

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

  test('练习写入指定文件夹，再导出一份副本', () async {
    final dir = Directory.systemTemp.createTempSync('study_archive_');
    final archive = LocalArchive(directory: dir);
    final saved = await archive.addPractice(
      subject: '语',
      body: '指出太阳是「日」',
      at: DateTime.utc(2026, 10, 17, 1, 2, 3),
    );
    expect(saved.records, hasLength(1));
    final loaded = await archive.load();
    expect(loaded.records.single.body, '指出太阳是「日」');
    final copy = await archive.exportCopy();
    expect(copy.existsSync(), isTrue);
    expect(copy.path, contains('study_archive_'));
    dir.deleteSync(recursive: true);
  });

  test('监护人观察和练习写在同一份档案里', () async {
    final dir = Directory.systemTemp.createTempSync('study_archive_');
    final archive = LocalArchive(directory: dir);
    await archive.addPractice(subject: '语', body: '指出太阳是「日」');
    final saved = await archive.addObservation(body: '对声音有反应');
    expect(saved.records, hasLength(2));
    expect(saved.records.last.source, '监护人观察');
    expect(saved.records.last.subject, '照护');
    expect(saved.records.last.body, '对声音有反应');
    dir.deleteSync(recursive: true);
  });

  test('带概念 id 的练习可以写入再读出', () async {
    final dir = Directory.systemTemp.createTempSync('study_archive_');
    final archive = LocalArchive(directory: dir);
    final saved = await archive.addPractice(
      subject: '语',
      body: '指出太阳是「日」',
      conceptId: 'zi_ri',
      domainId: 'language',
      ageBandId: 'toddler',
    );
    final loaded = await archive.load();
    expect(loaded.records.single.conceptId, 'zi_ri');
    expect(loaded.records.single.domainId, 'language');
    expect(loaded.records.single.ageBandId, 'toddler');
    expect(saved.records, hasLength(1));
    dir.deleteSync(recursive: true);
  });

  test('同一概念在不同年龄只换呈现，不重复建节点', () {
    final graph = KnowledgeGraph.defaults;
    final fire = graph.conceptById('fire_safety')!;
    expect(fire.variantFor(AgeBand.toddler).topic, '看见火要远离');
    expect(fire.variantFor(AgeBand.middleSchool).topic, '燃烧三要素');
    expect(fire.variantFor(AgeBand.college).topic, '火灾动力学与逃生限制');
    expect(fire.availableIn(AgeBand.highSchool), isFalse);
  });

  test('领域阶梯从浅到深排序，未满足前置的格锁定', () {
    final graph = KnowledgeGraph.defaults;
    final domain = graph.domainById('language')!;
    final entries = buildLadder(
      graph: graph,
      domain: domain,
      band: AgeBand.upperPrimary,
      learner: LearnerState(const {}),
    );
    expect(
      entries.map((entry) => entry.concept.id).toList(),
      ['zi_ri', 'read_notice', 'own_note'],
    );
    expect(entries.first.status, LadderStatus.available);
    expect(entries[1].status, LadderStatus.locked);
    expect(entries[1].canOpen, isFalse);
  });

  test('前置到了熟练，下一格才打开', () {
    final graph = KnowledgeGraph.defaults;
    final domain = graph.domainById('language')!;
    final learner = LearnerState(const {'zi_ri': 4});
    final entries = buildLadder(
      graph: graph,
      domain: domain,
      band: AgeBand.upperPrimary,
      learner: learner,
    );
    expect(entries[1].status, LadderStatus.available);
    expect(entries[2].status, LadderStatus.locked);
    expect(entries[1].canOpen, isTrue);
  });

  test('今日下一步跳过已熟练的，关注领域优先', () {
    final graph = KnowledgeGraph.defaults;
    expect(graph.nextStep(AgeBand.toddler, const {})?.id, 'zi_ri');
    expect(
      graph.nextStep(
        AgeBand.toddler,
        const {},
        focusDomainId: 'life',
      )?.id,
      'fire_safety',
    );
    expect(
      graph.nextStep(AgeBand.toddler, const {'zi_ri', 'count_objects', 'fire_safety'}),
      isNull,
    );
  });

  test('前置不在本档时不阻塞，换到高中仍有下一步', () {
    final graph = KnowledgeGraph.defaults;
    final next = graph.nextStep(AgeBand.highSchool, const {});
    expect(next, isNotNull);
    // 高中里最浅的一格是数学，它的前置「数实物」不在高中目录里。
    expect(next!.id, 'fraction');
  });

  test('练习次数推出四档，熟练才解锁下一项', () {
    expect(tierFromCount(1), MasteryTier.attempt);
    expect(tierFromCount(2), MasteryTier.familiar);
    expect(tierFromCount(4), MasteryTier.skilled);
    expect(tierFromCount(5), MasteryTier.mastered);
    final learner = LearnerState.fromRecords([
      LearningRecord(
        id: '1',
        at: DateTime.utc(2026, 10, 17),
        source: '应用内练习',
        subject: '语',
        body: '指出太阳是「日」',
        conceptId: 'zi_ri',
      ),
    ]);
    expect(learner.tierOf('zi_ri'), MasteryTier.attempt);
    expect(learner.readyIds.isEmpty, isTrue);
  });
}
