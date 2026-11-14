import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/archive/learning_record.dart';
import 'package:study_app/learning/ladder.dart';
import 'package:study_app/learning/learner_state.dart';
import 'package:study_app/learning/mastery.dart';

import 'support/study_fixture.dart';

void main() {
  final catalog = installTestCatalog();
  final graph = catalog.graph;

  test('同一概念在不同年龄只换呈现，不重复建节点', () {
    final fire = graph.conceptById('fire_safety')!;
    expect(fire.variantFor(testBand('toddler')).topic, '看见火要远离');
    expect(fire.variantFor(testBand('middle_school')).topic, '燃烧三要素');
    expect(fire.variantFor(testBand('college')).topic, '火灾动力学与逃生限制');
    expect(fire.availableIn(testBand('high_school')), isFalse);
  });

  test('领域阶梯从浅到深排序，未满足前置的格锁定', () {
    final category = graph.categoryById('language')!;
    final entries = buildLadder(
      graph: graph,
      category: category,
      band: testBand('upper_primary'),
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
    final category = graph.categoryById('language')!;
    final learner = LearnerState(const {'zi_ri': 4});
    final entries = buildLadder(
      graph: graph,
      category: category,
      band: testBand('upper_primary'),
      learner: learner,
    );
    expect(entries[1].status, LadderStatus.available);
    expect(entries[2].status, LadderStatus.locked);
    expect(entries[1].canOpen, isTrue);
  });

  test('今日下一步跳过已熟练的，关注分类优先', () {
    expect(graph.nextStep(testBand('toddler'), const {})?.id, 'zi_ri');
    expect(
      graph.nextStep(
        testBand('toddler'),
        const {},
        focusCategoryId: 'cat_life',
      )?.id,
      'fire_safety',
    );
    expect(
      graph.nextStep(
        testBand('toddler'),
        const {'zi_ri', 'count_objects', 'fire_safety'},
      ),
      isNull,
    );
  });

  test('前置不在本档时不阻塞，换到高中仍有下一步', () {
    final next = graph.nextStep(testBand('high_school'), const {});
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
