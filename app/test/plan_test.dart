import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/main.dart';
import 'package:study_app/plan/plan_text.dart';
import 'package:study_app/plan/study_plan.dart';

import 'support/study_fixture.dart';

void main() {
  installTestCatalog();

  test('计划保存后能原样读回', () async {
    final study = await TestStudy.create();
    addTearDown(study.dispose);

    final start = DateTime(2026, 11, 9, 19, 30);
    final plan = StudyPlan(
      id: 'p1',
      domainId: 'language',
      depth: PlanDepth.deep,
      startAt: start,
      remind: true,
    );
    await study.planStore.save([plan]);

    final loaded = await study.planStore.load();
    expect(loaded.single.id, 'p1');
    expect(loaded.single.domainId, 'language');
    expect(loaded.single.depth, PlanDepth.deep);
    expect(loaded.single.startAt, start);
    expect(loaded.single.remind, isTrue);
    expect(loaded.single.remindedAt, isNull);
    expect(study.api.saveCount, 1);
  });

  test('坏掉的计划条目会被跳过，不影响启动', () async {
    final api = FakeStudyApi(
      userData: {
        'profile': {'band': null, 'focusDomainId': null},
        'plans': [
          {'bad': true},
        ],
        'records': <Object?>[],
      },
    );
    final study = await TestStudy.create(api: api);
    addTearDown(study.dispose);

    expect(await study.planStore.load(), isEmpty);
  });

  test('知识级计划带概念 id 和学习程度，能原样读回', () async {
    final study = await TestStudy.create();
    addTearDown(study.dispose);

    final plan = StudyPlan(
      id: 'p2',
      domainId: 'language',
      depth: PlanDepth.deep,
      conceptId: 'zi_ri',
      degree: testDegree('familiar'),
      startAt: DateTime(2026, 11, 11, 20),
      remind: false,
    );
    await study.planStore.save([plan]);

    final loaded = await study.planStore.load();
    expect(loaded.single.conceptId, 'zi_ri');
    expect(loaded.single.degree?.id, 'familiar');
    expect(loaded.single.isConceptPlan, isTrue);
  });

  test('领域级旧计划没有概念 id，读回后仍是领域级', () async {
    final study = await TestStudy.create();
    addTearDown(study.dispose);

    final plan = StudyPlan(
      id: 'p1',
      domainId: 'language',
      depth: PlanDepth.brief,
      startAt: DateTime(2026, 11, 11, 8),
    );
    await study.planStore.save([plan]);

    final loaded = await study.planStore.load();
    expect(loaded.single.conceptId, isNull);
    expect(loaded.single.isConceptPlan, isFalse);
  });

  test('计划时间写法区分今天、明天和更远', () {
    final now = DateTime(2026, 11, 8, 20);
    expect(planTimeLabel(DateTime(2026, 11, 8, 19, 30), now: now), '今天 19:30');
    expect(planTimeLabel(DateTime(2026, 11, 9, 8, 5), now: now), '明天 08:05');
    expect(planTimeLabel(DateTime(2026, 11, 20, 9, 0), now: now), '11月20日 09:00');
  });

  testWidgets('从知识详情页按程度加入计划，写进数据库', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final study = await TestStudy.create(band: 'lower_primary');
    addTearDown(study.dispose);

    await tester.pumpWidget(StudyApp(repository: study.repository));
    await tester.pumpAndSettle();

    // 知识库 → 点「日」的知识卡 → 详情页按「入门」加入计划。
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('knowledge_zi_ri')));
    await tester.pumpAndSettle();
    expect(find.text('「入门」要学的知识点'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add_to_plan')));
    await tester.pumpAndSettle();

    final loaded = await study.planStore.load();
    expect(loaded.single.conceptId, 'zi_ri');
    expect(loaded.single.degree?.id, 'beginner');
    expect(loaded.single.domainId, 'language');
    expect(find.textContaining('已加入计划'), findsOneWidget);
  });

  testWidgets('到点的计划会提醒一次', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final study = await TestStudy.create(
      band: 'lower_primary',
      plans: [
        StudyPlan(
          id: 'due',
          domainId: 'language',
          depth: PlanDepth.brief,
          startAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      ],
    );
    addTearDown(study.dispose);

    await tester.pumpWidget(StudyApp(repository: study.repository));
    await tester.pumpAndSettle();

    expect(find.text('计划到时间了'), findsOneWidget);
    await tester.tap(find.text('稍后'));
    await tester.pumpAndSettle();
    expect(find.text('计划到时间了'), findsNothing);

    // 点「稍后」只是推迟再提醒，不算已经提醒过。
    final loaded = await study.planStore.load();
    expect(loaded.single.remindedAt, isNull);
    expect(loaded.single.snoozedUntil, isNotNull);
  });
}
