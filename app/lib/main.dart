import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_brand.dart';
import 'archive/local_archive.dart';
import 'plan/local_plan_store.dart';
import 'profile/local_profile.dart';
import 'ui/bootstrap_page.dart';
import 'ui/theme.dart';

void main() {
  runApp(const StudyApp());
}

/// 应用入口。测试可以直接注入档案、档位与计划存储，避免写到真实目录。
class StudyApp extends StatelessWidget {
  const StudyApp({super.key, this.archive, this.store, this.planStore});

  final LocalArchive? archive;
  final LocalProfile? store;
  final LocalPlanStore? planStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppBrand.name,
      theme: buildPaperTheme(),
      // 日期与时刻选择用中文，避免系统弹窗里出现英文。
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: StartPage(
        archive: archive,
        store: store,
        planStore: planStore,
      ),
    );
  }
}
