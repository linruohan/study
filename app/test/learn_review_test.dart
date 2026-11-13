import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/archive/learning_record.dart';
import 'package:study_app/main.dart';
import 'package:study_app/plan/study_plan.dart';
import 'package:study_app/ui/review_page.dart';
import 'package:study_app/ui/theme.dart';

import 'support/study_fixture.dart';

void main() {
  installTestCatalog();

  testWidgets('规划页按领域分组，学习中与未开始分列', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final study = await TestStudy.create(
      band: 'lower_primary',
      records: [
        LearningRecord(
          id: 'r1',
          at: DateTime(2026, 11, 6, 19),
          source: '应用内练习',
          subject: '语',
          body: '说一句带「日」的话',
          conceptId: 'zi_ri',
          domainId: 'language',
          ageBandId: 'lower_primary',
        ),
      ],
      plans: [
        StudyPlan(
          id: 'p1',
          domainId: 'language',
          depth: PlanDepth.deep,
          conceptId: 'zi_ri',
          degree: testDegree('beginner'),
          startAt: DateTime(2026, 11, 7, 19, 30),
          remind: false,
        ),
        StudyPlan(
          id: 'p2',
          domainId: 'language',
          depth: PlanDepth.deep,
          conceptId: 'read_notice',
          degree: testDegree('familiar'),
          startAt: DateTime(2026, 11, 9, 8),
          remind: false,
        ),
      ],
    );
    addTearDown(study.dispose);

    await tester.pumpWidget(StudyApp(repository: study.repository));
    await tester.pumpAndSettle();

    // 默认就在「规划」页：zi_ri 有练习记录进「学习中」，
    // read_notice 还没练过进「未开始」。段标题带数量，和卡片状态标签区分开。
    expect(find.text('学习中 · 1 条'), findsOneWidget);
    expect(find.text('未开始 · 1 条'), findsOneWidget);
    expect(find.text('用「日」写一句话'), findsOneWidget);
    expect(find.text('读懂一则校园通知'), findsOneWidget);
  });

  testWidgets('点计划里的知识进入按程度学习页，勾选写入档案', (WidgetTester tester) async {
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
          id: 'p1',
          domainId: 'language',
          depth: PlanDepth.deep,
          conceptId: 'zi_ri',
          degree: testDegree('beginner'),
          startAt: DateTime(2026, 11, 7, 19, 30),
          remind: false,
        ),
      ],
    );
    addTearDown(study.dispose);

    await tester.pumpWidget(StudyApp(repository: study.repository));
    await tester.pumpAndSettle();

    // 点「未开始」里的知识，进入入门程度的学习页。
    await tester.tap(find.byKey(const Key('plan_concept_zi_ri')));
    await tester.pumpAndSettle();
    expect(find.text('入门程度 · 用「日」写一句话'), findsOneWidget);

    // 勾第一个知识点，写一条带概念 id 的记录。
    await tester.tap(find.byKey(const Key('degree_point_0')));
    await tester.pumpAndSettle();
    final loaded = await study.archiveStore.load();
    expect(
      loaded.records.last.body,
      '入门 · 用「日」写一句话',
    );
    expect(loaded.records.last.conceptId, 'zi_ri');
  });

  testWidgets('小测逐题勾选、监护人确认后提交再记一次', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final study = await TestStudy.create(
      band: 'lower_primary',
      records: [
        LearningRecord(
          id: 'r1',
          at: DateTime(2026, 11, 6, 19),
          source: '应用内练习',
          subject: '语',
          body: '说一句带「日」的话',
          conceptId: 'zi_ri',
          domainId: 'language',
          ageBandId: 'lower_primary',
        ),
      ],
    );
    addTearDown(study.dispose);

    final domain = study.repository.catalog.graph.domainById('language')!;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildPaperTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                key: const Key('open_review'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<bool>(
                    builder: (_) => ReviewPage(
                      archive: study.archiveStore,
                      band: testBand('lower_primary'),
                      domain: domain,
                    ),
                  ),
                ),
                child: const Text('打开小测'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open_review')));
    await tester.pumpAndSettle();

    expect(find.text('学完这几步，答一答'), findsOneWidget);
    expect(find.text('「日」在这句里是太阳，还是日子？'), findsOneWidget);

    // 没有勾选和确认时，提交按钮不可用。
    final before = tester.widget<FilledButton>(
      find.byKey(const Key('submit_review')),
    );
    expect(before.onPressed, isNull);

    await tester.tap(find.text('看一句回应'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('review_check_zi_ri')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('review_confirm')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('submit_review')));
    await tester.pumpAndSettle();

    // 回到打开小测的页面，档案里多了一条小测记录。
    expect(find.text('打开小测'), findsOneWidget);
    final loaded = await study.archiveStore.load();
    expect(loaded.records.length, 2);
    expect(loaded.records.last.body, contains('完成小测'));
  });
}
