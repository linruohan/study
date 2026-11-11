import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/archive/local_archive.dart';
import 'package:study_app/knowledge/age_band.dart';
import 'package:study_app/knowledge/knowledge_graph.dart';
import 'package:study_app/knowledge/study_degree.dart';
import 'package:study_app/main.dart';
import 'package:study_app/plan/local_plan_store.dart';
import 'package:study_app/plan/study_plan.dart';
import 'package:study_app/profile/local_profile.dart';
import 'package:study_app/ui/review_page.dart';
import 'package:study_app/ui/theme.dart';

void main() {
  testWidgets('规划页按领域分组，学习中与未开始分列', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final dir = Directory.systemTemp.createTempSync('lumen_learn_');
    final store = LocalProfile(directory: dir);
    final archive = LocalArchive(directory: dir);
    await archive.addPractice(
      subject: '语',
      body: '说一句带「日」的话',
      conceptId: 'zi_ri',
      domainId: 'language',
      ageBandId: 'lower_primary',
    );
    await store.save(const StudyProfile(band: AgeBand.lowerPrimary));
    await LocalPlanStore(directory: dir).save([
      StudyPlan(
        id: 'p1',
        domainId: 'language',
        depth: PlanDepth.deep,
        conceptId: 'zi_ri',
        degree: StudyDegree.beginner,
        startAt: DateTime(2026, 11, 7, 19, 30),
        remind: false,
      ),
      StudyPlan(
        id: 'p2',
        domainId: 'language',
        depth: PlanDepth.deep,
        conceptId: 'read_notice',
        degree: StudyDegree.familiar,
        startAt: DateTime(2026, 11, 9, 8),
        remind: false,
      ),
    ]);
    await tester.pumpWidget(
      StudyApp(
        archive: archive,
        store: store,
        planStore: LocalPlanStore(directory: dir),
      ),
    );
    await tester.pumpAndSettle();

    // 默认就在「规划」页：zi_ri 有练习记录进「学习中」，
    // read_notice 还没练过进「未开始」。段标题带数量，和卡片状态标签区分开。
    expect(find.text('学习中 · 1 条'), findsOneWidget);
    expect(find.text('未开始 · 1 条'), findsOneWidget);
    expect(find.text('用「日」写一句话'), findsOneWidget);
    expect(find.text('读懂一则校园通知'), findsOneWidget);
    dir.deleteSync(recursive: true);
  });

  testWidgets('点计划里的知识进入按程度学习页，勾选写入档案', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final dir = Directory.systemTemp.createTempSync('lumen_tab_');
    final store = LocalProfile(directory: dir);
    final archive = LocalArchive(directory: dir);
    await store.save(const StudyProfile(band: AgeBand.lowerPrimary));
    await LocalPlanStore(directory: dir).save([
      StudyPlan(
        id: 'p1',
        domainId: 'language',
        depth: PlanDepth.deep,
        conceptId: 'zi_ri',
        degree: StudyDegree.beginner,
        startAt: DateTime(2026, 11, 7, 19, 30),
        remind: false,
      ),
    ]);
    await tester.pumpWidget(
      StudyApp(
        archive: archive,
        store: store,
        planStore: LocalPlanStore(directory: dir),
      ),
    );
    await tester.pumpAndSettle();

    // 点「未开始」里的知识，进入入门程度的学习页。
    await tester.tap(find.byKey(const Key('plan_concept_zi_ri')));
    await tester.pumpAndSettle();
    expect(find.text('入门程度 · 用「日」写一句话'), findsOneWidget);

    // 勾第一个知识点，写一条带概念 id 的记录。
    await tester.tap(find.byKey(const Key('degree_point_0')));
    await tester.pumpAndSettle();
    final loaded = await archive.load();
    expect(
      loaded.records.last.body,
      '入门 · 用「日」写一句话',
    );
    expect(loaded.records.last.conceptId, 'zi_ri');
    dir.deleteSync(recursive: true);
  });

  testWidgets('小测逐题勾选、监护人确认后提交再记一次', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final dir = Directory.systemTemp.createTempSync('lumen_review_');
    final archive = LocalArchive(directory: dir);
    await archive.addPractice(
      subject: '语',
      body: '说一句带「日」的话',
      conceptId: 'zi_ri',
      domainId: 'language',
      ageBandId: 'lower_primary',
    );
    final domain = KnowledgeGraph.defaults.domainById('language')!;

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
                      archive: archive,
                      band: AgeBand.lowerPrimary,
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
    final loaded = await archive.load();
    expect(loaded.records.length, 2);
    expect(loaded.records.last.body, contains('完成小测'));
    dir.deleteSync(recursive: true);
  });
}
