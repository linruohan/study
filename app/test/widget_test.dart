import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/archive/local_archive.dart';
import 'package:study_app/main.dart';

void main() {
  testWidgets('点太阳后说出你能，并记下一条', (WidgetTester tester) async {
    final dir = Directory.systemTemp.createTempSync('study_ui_');
    await tester.pumpWidget(
      MaterialApp(home: TodayPage(archive: LocalArchive(directory: dir))),
    );
    await tester.pumpAndSettle();

    expect(find.text('点一点太阳'), findsOneWidget);
    expect(find.text('本机记录 0 条'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('sun')));
      for (var i = 0; i < 50 && dir.listSync().isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pump();

    expect(find.text('你能指出太阳是「日」'), findsOneWidget);
    expect(find.text('本机记录 1 条'), findsOneWidget);
    dir.deleteSync(recursive: true);
  });
}
