import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/main.dart';

import 'support/study_fixture.dart';

void main() {
  testWidgets('监护人记下对声音有反应，孩子的太阳还在', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final study = await TestStudy.create(band: 'toddler');
    addTearDown(study.dispose);

    await tester.pumpWidget(StudyApp(repository: study.repository));
    await tester.pumpAndSettle();

    // 监护人入口在「我的」里。
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    final guardianRow = find.byKey(const Key('profile_guardian'));
    await tester.scrollUntilVisible(guardianRow, 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(guardianRow);
    await tester.pumpAndSettle();
    expect(find.text('可以空着。空着不是落后。这是监护人的观察，不是孩子自己说的。'), findsOneWidget);
    expect(find.text('记录还不够。'), findsOneWidget);

    await tester.tap(find.text('对声音有反应'));
    await tester.pumpAndSettle();
    expect(find.text('记下了：对声音有反应'), findsOneWidget);
    expect(find.text('依据是监护人观察「对声音有反应」。'), findsOneWidget);
    expect(find.text('这不是教师、心理咨询师或医生的判断。'), findsOneWidget);
    expect(find.text('记录还不够。'), findsNothing);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('本机记录 1 条'), findsOneWidget);

    final loaded = await study.archiveStore.load();
    expect(loaded.records.single.source, '监护人观察');
    // 记录已经同步到数据库。
    expect(study.api.saveCount, 1);
  });
}
