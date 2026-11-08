import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/archive/local_archive.dart';
import 'package:study_app/knowledge/age_band.dart';
import 'package:study_app/knowledge/knowledge_graph.dart';
import 'package:study_app/main.dart';
import 'package:study_app/plan/local_plan_store.dart';
import 'package:study_app/plan/study_plan.dart';
import 'package:study_app/profile/local_profile.dart';
import 'package:study_app/ui/review_page.dart';
import 'package:study_app/ui/theme.dart';

void main() {
  testWidgets('计划按领域分组，显示学习程度', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final dir = Directory.systemTemp.createTempSync('lumen_learn_');
    final store = LocalProfile(directory: dir);
    await store.save(const StudyProfile(band: AgeBand.lowerPrimary));
    await LocalPlanStore(directory: dir).save([
      StudyPlan(
        id: 'p1',
        domainId: 'language',
        depth: PlanDepth.deep,
        startAt: DateTime(2026, 11, 7, 19, 30),
        remind: false,
      ),
      StudyPlan(
        id: 'p2',
        domainId: 'math',
        depth: PlanDepth.brief,
        startAt: DateTime(2026, 11, 9, 8),
        remind: false,
        done: true,
      ),
    ]);
    await tester.pumpWidget(
      StudyApp(
        archive: LocalArchive(directory: dir),
        store: store,
        planStore: LocalPlanStore(directory: dir),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('学习'));
    await tester.pumpAndSettle();
    expect(find.text('已加入计划'), findsOneWidget);
    expect(find.textContaining('深入学习'), findsWidgets);
    // 已完成的计划默认折起来，展开后才看得到。
    expect(find.textContaining('简单了解'), findsNothing);
    await tester.tap(find.byKey(const Key('done_toggle_math')));
    await tester.pumpAndSettle();
    expect(find.textContaining('简单了解'), findsWidgets);
    expect(find.text('已完成'), findsWidgets);
    dir.deleteSync(recursive: true);
  });

  testWidgets('知识库标签离开再回来仍停在原标签', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final dir = Directory.systemTemp.createTempSync('lumen_tab_');
    final store = LocalProfile(directory: dir);
    await store.save(const StudyProfile(band: AgeBand.lowerPrimary));
    await tester.pumpWidget(
      StudyApp(
        archive: LocalArchive(directory: dir),
        store: store,
        planStore: LocalPlanStore(directory: dir),
      ),
    );
    await tester.pumpAndSettle();

    // 还没有练过的知识，「学习中」是空的。
    await tester.tap(find.byKey(const Key('library_tab_1')));
    await tester.pumpAndSettle();
    expect(find.text('这一组还没有知识'), findsOneWidget);

    // 去「学习」再回来，仍停在「学习中」。
    await tester.tap(find.byIcon(Icons.school_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pumpAndSettle();
    expect(find.text('这一组还没有知识'), findsOneWidget);
    expect(find.byKey(const Key('knowledge_zi_ri')), findsNothing);
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
