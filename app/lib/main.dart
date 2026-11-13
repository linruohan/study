import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_brand.dart';
import 'data/study_repository.dart';
import 'ui/bootstrap_page.dart';
import 'ui/theme.dart';

void main() {
  runApp(const StudyApp());
}

/// 应用入口。测试可以注入假仓库，避免访问真实服务。
class StudyApp extends StatelessWidget {
  const StudyApp({super.key, this.repository});

  final StudyRepository? repository;

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
      home: StartPage(repository: repository),
    );
  }
}
