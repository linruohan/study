import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:study_app/data/device_id_store.dart';
import 'package:study_app/data/study_api.dart';
import 'package:study_app/data/study_cache.dart';
import 'package:study_app/data/study_repository.dart';
import 'package:study_app/main.dart';

/// 在 Windows 上点击真实界面，使用真实 API 和独立临时目录验证完整学习流程。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('选年龄、今日一步、加入计划、记录练习并在重启后读回', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final directory = await Directory.systemTemp.createTemp('study_windows_e2e_');
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    /// 每次启动都新建仓库，但共享同一份设备标识与缓存目录。
    StudyRepository createRepository() {
      return StudyRepository(
        api: HttpStudyApi(),
        cache: FileStudyCache(directory: directory),
        device: FileDeviceIdStore(directory: directory),
      );
    }

    final first = createRepository();
    await tester.pumpWidget(StudyApp(repository: first));
    await tester.pumpAndSettle();

    expect(find.text('你现在在哪一档'), findsOneWidget);
    await tester.tap(find.byKey(const Key('band_toddler')));
    await tester.pumpAndSettle();
    expect(first.profile.band?.id, 'toddler');

    await tester.tap(find.byIcon(Icons.school_outlined));
    await tester.pumpAndSettle();
    expect(find.text('今日一步'), findsOneWidget);
    expect(find.text('认一认「日」'), findsOneWidget);

    await tester.tap(find.byKey(const Key('zi_ri')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('touch_zi_ri')));
    await tester.pumpAndSettle();
    expect(find.text('你能指出太阳是「日」'), findsOneWidget);

    await tester.tap(find.text('回到学习'));
    await tester.pumpAndSettle();
    expect(find.text('本机记录 1 条'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('knowledge_zi_ri')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add_to_plan')));
    await tester.pumpAndSettle();
    expect(find.textContaining('已加入计划'), findsOneWidget);

    expect(first.plans.single.conceptId, 'zi_ri');
    expect(first.plans.single.degree?.id, 'beginner');
    expect(first.archive.records.single.conceptId, 'zi_ri');

    final deviceId = await FileDeviceIdStore(directory: directory).read();
    final remote = await HttpStudyApi().fetchUserData(deviceId);
    final remoteProfile = remote['profile']! as Map<String, dynamic>;
    final remotePlans = remote['plans']! as List<dynamic>;
    final remoteRecords = remote['records']! as List<dynamic>;
    expect(remoteProfile['band'], 'toddler');
    expect(remotePlans, hasLength(1));
    expect(remoteRecords, hasLength(1));
    debugPrint('WINDOWS_E2E_DEVICE=$deviceId');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    final restarted = createRepository();
    await tester.pumpWidget(StudyApp(repository: restarted));
    await tester.pumpAndSettle();

    expect(find.text('你现在在哪一档'), findsNothing);
    expect(restarted.profile.band?.id, 'toddler');
    expect(restarted.plans.single.conceptId, 'zi_ri');
    expect(restarted.archive.records.single.conceptId, 'zi_ri');
    expect(find.byKey(const Key('plan_concept_zi_ri')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.school_outlined));
    await tester.pumpAndSettle();
    expect(find.text('本机记录 1 条'), findsOneWidget);
  });

  testWidgets('断网用缓存启动，离线记录并在恢复后自动同步', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final directory = await Directory.systemTemp.createTemp('study_offline_e2e_');
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    // 先取一个当前未监听的端口，再关闭 socket，让离线请求得到真实连接失败。
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final offlineUrl = 'http://127.0.0.1:${socket.port}';
    await socket.close();

    /// 在线时访问真实 API，离线时访问未监听端口，共享同一份文件缓存。
    StudyRepository createRepository({required bool offline}) {
      return StudyRepository(
        api: HttpStudyApi(baseUrl: offline ? offlineUrl : null),
        cache: FileStudyCache(directory: directory),
        device: FileDeviceIdStore(directory: directory),
      );
    }

    final online = createRepository(offline: false);
    await tester.pumpWidget(StudyApp(repository: online));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('band_toddler')));
    await tester.pumpAndSettle();
    expect(online.loadedSnapshot?.fromCache, isFalse);
    expect(online.profile.band?.id, 'toddler');

    final deviceId = await FileDeviceIdStore(directory: directory).read();

    // 第一次断网启动：知识和年龄档都来自最近一次成功缓存。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final offline = createRepository(offline: true);
    await tester.pumpWidget(StudyApp(repository: offline));
    await tester.pumpAndSettle();

    expect(offline.loadedSnapshot?.fromCache, isTrue);
    expect(offline.pending, isFalse);
    expect(offline.profile.band?.id, 'toddler');
    expect(find.text('你现在在哪一档'), findsNothing);

    await tester.tap(find.byIcon(Icons.school_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('zi_ri')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('touch_zi_ri')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('回到学习'));
    await tester.pumpAndSettle();

    expect(find.text('本机记录 1 条'), findsOneWidget);
    expect(offline.archive.records.single.conceptId, 'zi_ri');
    expect(offline.pending, isTrue);
    final offlineRecordId = offline.archive.records.single.id;

    final pendingCache = await FileStudyCache(directory: directory).read();
    expect(pendingCache, isNotNull);
    expect(pendingCache!.pending, isTrue);
    expect(pendingCache.userData['records']! as List<dynamic>, hasLength(1));

    // 离线记录尚未到达真实服务端，不能把缓存写入误认为已经同步。
    final beforeRecovery = await HttpStudyApi().fetchUserData(deviceId);
    expect(beforeRecovery['records']! as List<dynamic>, isEmpty);

    // 第二次断网启动：待同步记录在应用重启后仍然保留。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final offlineRestart = createRepository(offline: true);
    await tester.pumpWidget(StudyApp(repository: offlineRestart));
    await tester.pumpAndSettle();

    expect(offlineRestart.loadedSnapshot?.fromCache, isTrue);
    expect(offlineRestart.pending, isTrue);
    expect(offlineRestart.archive.records.single.id, offlineRecordId);
    await tester.tap(find.byIcon(Icons.school_outlined));
    await tester.pumpAndSettle();
    expect(find.text('本机记录 1 条'), findsOneWidget);

    // 恢复真实 API：启动时先推待同步缓存，再拉取并保存最新快照。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final recovered = createRepository(offline: false);
    await tester.pumpWidget(StudyApp(repository: recovered));
    await tester.pumpAndSettle();

    expect(recovered.loadedSnapshot?.fromCache, isFalse);
    expect(recovered.pending, isFalse);
    expect(recovered.archive.records.single.id, offlineRecordId);
    expect(recovered.profile.band?.id, 'toddler');

    final recoveredCache = await FileStudyCache(directory: directory).read();
    expect(recoveredCache, isNotNull);
    expect(recoveredCache!.pending, isFalse);

    final remote = await HttpStudyApi().fetchUserData(deviceId);
    final remoteRecords = remote['records']! as List<dynamic>;
    final remoteRecord = remoteRecords.single as Map<String, dynamic>;
    expect(remoteRecord['id'], offlineRecordId);
    expect(remoteRecord['conceptId'], 'zi_ri');
    debugPrint('WINDOWS_OFFLINE_E2E_DEVICE=$deviceId');

    await tester.tap(find.byIcon(Icons.school_outlined));
    await tester.pumpAndSettle();
    expect(find.text('本机记录 1 条'), findsOneWidget);
  });
}
