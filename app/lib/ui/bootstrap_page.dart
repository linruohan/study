import 'package:flutter/material.dart';

import '../archive/local_archive.dart';
import '../knowledge/age_band.dart';
import '../plan/local_plan_store.dart';
import '../profile/local_profile.dart';
import 'age_setup_page.dart';
import 'home_page.dart';
import 'theme.dart';

/// 启动页：读取本机档位，没有档位就先选年龄。
class StartPage extends StatefulWidget {
  const StartPage({super.key, this.archive, this.store, this.planStore});

  /// 测试可注入临时档案目录；为空时用真实文档目录。
  final LocalArchive? archive;

  /// 测试可注入临时设置目录；为空时用真实文档目录。
  final LocalProfile? store;

  /// 测试可注入临时计划目录；为空时用真实文档目录。
  final LocalPlanStore? planStore;

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  late final LocalArchive _archive = widget.archive ?? LocalArchive();
  late final LocalProfile _store = widget.store ?? LocalProfile();
  late final LocalPlanStore _planStore = widget.planStore ?? LocalPlanStore();
  StudyProfile? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await _store.load();
    if (!mounted) {
      return;
    }
    setState(() => _profile = profile);
  }

  /// 年龄选择完成以后，直接进入对应档位的首页。
  void _onChosen(AgeBand band) {
    setState(() => _profile = StudyProfile(band: band));
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    if (profile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: paperOchre)),
      );
    }
    if (profile.band == null) {
      return AgeSetupPage(store: _store, onChosen: _onChosen);
    }
    return HomePage(
      archive: _archive,
      store: _store,
      planStore: _planStore,
      profile: profile,
    );
  }
}
