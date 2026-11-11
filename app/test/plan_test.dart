import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/archive/local_archive.dart';
import 'package:study_app/knowledge/age_band.dart';
import 'package:study_app/main.dart';
import 'package:study_app/plan/local_plan_store.dart';
import 'package:study_app/plan/plan_text.dart';
import 'package:study_app/plan/study_plan.dart';
import 'package:study_app/profile/local_profile.dart';

void main() {
  test('计划存入本机后能原样读回', () async {
    final dir = Directory.systemTemp.createTempSync('lumen_plan_');
    final store = LocalPlanStore(directory: dir);
    final start = DateTime(2026, 11, 9, 19, 30);
    final plan = StudyPlan(
      id: 'p1',
      domainId: 'language',
      depth: PlanDepth.deep,
      startAt: start,
      remind: true,
    );
    await store.save([plan]);

    final loaded = await store.load();
    expect(loaded.single.id, 'p1');
    expect(loaded.single.domainId, 'language');
    expect(loaded.single.depth, PlanDepth.deep);
    expect(loaded.single.startAt, start);
    expect(loaded.single.remind, isTrue);
    expect(loaded.single.remindedAt, isNull);
    dir.deleteSync(recursive: true);
  });

  test('坏掉的计划文件不会让启动失败', () async {
    final dir = Directory.systemTemp.createTempSync('lumen_plan_');
    final store = LocalPlanStore(directory: dir);
    final file = File('${dir.path}${Platform.pathSeparator}study_plans.json');
    file.writeAsStringSync('{ 坏掉的 JSON');
    expect(await store.load(), isEmpty);
    dir.deleteSync(recursive: true);
  });

  test('计划时间写法区分今天、明天和更远', () {
    final now = DateTime(2026, 11, 8, 20);
    expect(planTimeLabel(DateTime(2026, 11, 8, 19, 30), now: now), '今天 19:30');
    expect(planTimeLabel(DateTime(2026, 11, 9, 8, 5), now: now), '明天 08:05');
    expect(planTimeLabel(DateTime(2026, 11, 20, 9, 0), now: now), '11月20日 09:00');
  });

  testWidgets('新建一条深入学习计划，写进本机', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final dir = Directory.systemTemp.createTempSync('lumen_plan_ui_');
    final store = LocalProfile(directory: dir);
    final planStore = LocalPlanStore(directory: dir);
    await store.save(const StudyProfile(band: AgeBand.lowerPrimary));
    await tester.pumpWidget(
      StudyApp(
        archive: LocalArchive(directory: dir),
        store: store,
        planStore: planStore,
      ),
    );
    await tester.pumpAndSettle();

    // 计划放在「规划」入口里，默认就停在这一页。
    expect(find.text('还没有学习计划'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add_plan')));
    await tester.pumpAndSettle();
    expect(find.text('选一个领域'), findsOneWidget);

    await tester.tap(find.byKey(const Key('plan_depth_deep')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('现在'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save_plan')));
    await tester.pumpAndSettle();

    expect(find.textContaining('到点提醒'), findsOneWidget);
    final loaded = await planStore.load();
    expect(loaded.single.depth, PlanDepth.deep);
    expect(loaded.single.remind, isTrue);
    expect(loaded.single.domainId, 'language');
    dir.deleteSync(recursive: true);
  });

  testWidgets('到点的计划会提醒一次', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final dir = Directory.systemTemp.createTempSync('lumen_plan_ui_');
    final store = LocalProfile(directory: dir);
    final planStore = LocalPlanStore(directory: dir);
    await store.save(const StudyProfile(band: AgeBand.lowerPrimary));
    await planStore.save([
      StudyPlan(
        id: 'due',
        domainId: 'language',
        depth: PlanDepth.brief,
        startAt: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
    ]);
    await tester.pumpWidget(
      StudyApp(
        archive: LocalArchive(directory: dir),
        store: store,
        planStore: planStore,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('计划到时间了'), findsOneWidget);
    await tester.tap(find.text('稍后'));
    await tester.pumpAndSettle();
    expect(find.text('计划到时间了'), findsNothing);

    // 点「稍后」只是推迟再提醒，不算已经提醒过。
    final loaded = await planStore.load();
    expect(loaded.single.remindedAt, isNull);
    expect(loaded.single.snoozedUntil, isNotNull);
    dir.deleteSync(recursive: true);
  });
}
