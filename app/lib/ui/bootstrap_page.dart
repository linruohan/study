import 'package:flutter/material.dart';

import '../archive/archive_store.dart';
import '../data/study_repository.dart';
import '../data/study_api.dart';
import '../knowledge/age_band.dart';
import '../plan/plan_store.dart';
import '../profile/profile_store.dart';
import '../profile/study_profile.dart';
import 'age_setup_page.dart';
import 'home_page.dart';
import 'theme.dart';

/// 启动页：先从数据库加载知识与设备数据，没有年龄档就先选年龄。
///
/// 网络失败但本机有缓存时自动使用缓存；两者都没有才显示加载失败。
class StartPage extends StatefulWidget {
  const StartPage({super.key, this.repository});

  /// 测试可注入假仓库，生产环境为空时使用真实接口。
  final StudyRepository? repository;

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  late final StudyRepository _repository =
      widget.repository ?? StudyRepository();
  late final ProfileStore _store = ProfileStore(_repository);
  late final PlanStore _planStore = PlanStore(_repository);
  late final ArchiveStore _archive = ArchiveStore(_repository);

  StudySnapshot? _snapshot;
  Object? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    // 测试或外部已经加载过时，直接用现成快照，避免重复拉取。
    final loaded = _repository.loadedSnapshot;
    if (loaded != null) {
      _snapshot = loaded;
      _loading = false;
      return;
    }
    _load();
  }

  /// 加载知识库与设备数据；失败时保留错误，让用户重试。
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await _repository.load();
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  /// 年龄选择完成以后，直接进入对应档位的首页。
  void _onChosen(AgeBand band) {
    final current = _snapshot;
    if (current == null) {
      return;
    }
    setState(() {
      _snapshot = StudySnapshot(
        catalog: current.catalog,
        profile: StudyProfile(
          band: band,
          focusDomainId: current.profile.focusDomainId,
        ),
        plans: current.plans,
        archive: current.archive,
        fromCache: current.fromCache,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: paperOchre)),
      );
    }

    final error = _error;
    if (error != null) {
      return _LoadError(error: error, onRetry: _load);
    }

    final snapshot = _snapshot;
    if (snapshot == null) {
      return _LoadError(error: '没有加载到数据', onRetry: _load);
    }

    final profile = snapshot.profile;
    if (profile.band == null) {
      return AgeSetupPage(store: _store, onChosen: _onChosen);
    }
    return HomePage(
      archive: _archive,
      store: _store,
      planStore: _planStore,
      profile: profile,
      graph: snapshot.catalog.graph,
      repository: _repository,
    );
  }
}

/// 加载失败：只给原因和重试，不内置任何兜底知识。
class _LoadError extends StatelessWidget {
  const _LoadError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message =
        error is StudyApiException ? error.toString() : '数据加载失败，请稍后再试';
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 40, color: paperInkSoft),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '请确认本地服务已启动，或稍后再试。',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: paperInkSoft),
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: onRetry, child: const Text('重新加载')),
            ],
          ),
        ),
      ),
    );
  }
}
