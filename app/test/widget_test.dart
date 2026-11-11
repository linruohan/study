import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/archive/local_archive.dart';
import 'package:study_app/knowledge/age_band.dart';
import 'package:study_app/main.dart';
import 'package:study_app/plan/local_plan_store.dart';
import 'package:study_app/profile/local_profile.dart';

void main() {
  testWidgets('先选年龄档，再点今日一步，记下一条', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final dir = Directory.systemTemp.createTempSync('lumen_ui_');
    final archive = LocalArchive(directory: dir);
    final store = LocalProfile(directory: dir);
    await tester.pumpWidget(
      StudyApp(
        archive: archive,
        store: store,
        planStore: LocalPlanStore(directory: dir),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('你现在在哪一档'), findsOneWidget);
    await tester.tap(find.byKey(const Key('band_toddler')));
    await tester.pumpAndSettle();

    // 默认进入知识库；点底部「学习」才看到今日一步。
    await tester.tap(find.byIcon(Icons.school_outlined));
    await tester.pumpAndSettle();
    expect(find.text('今日一步'), findsOneWidget);
    expect(find.text('认一认「日」'), findsOneWidget);

    await tester.tap(find.byKey(const Key('zi_ri')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('touch_zi_ri')));
    await tester.pumpAndSettle();
    expect(find.text('你能指出太阳是「日」'), findsOneWidget);
    expect(find.text('尝试'), findsOneWidget);

    await tester.tap(find.text('回到学习'));
    await tester.pumpAndSettle();
    expect(find.text('本机记录 1 条'), findsOneWidget);

    final loaded = await archive.load();
    expect(loaded.records.single.conceptId, 'zi_ri');
    expect(loaded.records.single.ageBandId, 'toddler');
    dir.deleteSync(recursive: true);
  });

  testWidgets('已经选过年龄时直接进入对应档位', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final dir = Directory.systemTemp.createTempSync('lumen_ui_');
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

    expect(find.text('你现在在哪一档'), findsNothing);
    // 默认进入规划；切到「知识库」看这一档的知识卡片。
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('knowledge_zi_ri')), findsOneWidget);
    // 6–8 岁同一概念换成「写一句话」，不重复幼儿的点认。
    expect(find.text('用「日」写一句话'), findsOneWidget);
    dir.deleteSync(recursive: true);
  });
}
