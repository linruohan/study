import 'dart:async';

import 'package:flutter/material.dart';

import '../app_brand.dart';
import '../archive/local_archive.dart';
import '../guardian/guardian_page.dart';
import '../knowledge/age_band.dart';
import '../knowledge/concept.dart';
import '../knowledge/domain.dart';
import '../knowledge/knowledge_graph.dart';
import '../learning/learner_state.dart';
import '../plan/local_plan_store.dart';
import '../plan/study_plan.dart';
import '../profile/local_profile.dart';
import 'age_setup_page.dart';
import 'concept_page.dart';
import 'domain_page.dart';
import 'knowledge_detail_page.dart';
import 'learn_view.dart';
import 'library_view.dart';
import 'plan_editor_page.dart';
import 'profile_view.dart';
import 'review_page.dart';
import 'theme.dart';

/// 首页：知识库、学习、我的三个入口。
///
/// 知识库按程度和领域看全部知识；学习放今日一步与已排计划；
/// 我的放等级、徽章和设置。
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.archive,
    required this.store,
    required this.planStore,
    required this.profile,
    this.graph = KnowledgeGraph.defaults,
  });

  final LocalArchive archive;
  final LocalProfile store;
  final LocalPlanStore planStore;
  final StudyProfile profile;
  final KnowledgeGraph graph;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late StudyProfile _profile = widget.profile;
  LearnerState? _learner;
  var _recordCount = 0;
  var _tab = 0;

  /// 知识库停在哪个程度标签，返回详情后保持不动。
  var _libraryTab = 0;

  /// 学习页是否展开已完成计划，默认收起。
  var _showDonePlans = false;
  String? _exportPath;
  List<StudyPlan> _plans = const [];
  Timer? _reminderTimer;
  var _reminderOpen = false;

  @override
  void initState() {
    super.initState();
    _reload();
    _loadPlans();
    _reminderTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkPlanReminder(),
    );
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    super.dispose();
  }

  /// 重新读档案：记录、掌握档和今日一步都从这里更新。
  Future<void> _reload() async {
    final archive = await widget.archive.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _learner = LearnerState.fromRecords(archive.records);
      _recordCount = archive.records.length;
    });
  }

  /// 进入某一步学习；回来后重新读档案。
  Future<void> _openConcept(Concept concept, LearningDomain domain) async {
    final band = _profile.band;
    if (band == null) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConceptPage(
          archive: widget.archive,
          band: band,
          domain: domain,
          concept: concept,
        ),
      ),
    );
    await _reload();
  }

  /// 打开一条知识的详情；在详情里加入计划后，带回计划并切到「学习」。
  Future<void> _openKnowledge(Concept concept, LearningDomain domain) async {
    final band = _profile.band;
    final learner = _learner;
    if (band == null || learner == null) {
      return;
    }
    final plan = await Navigator.of(context).push<StudyPlan>(
      MaterialPageRoute<StudyPlan>(
        builder: (_) => KnowledgeDetailPage(
          archive: widget.archive,
          graph: widget.graph,
          band: band,
          domain: domain,
          concept: concept,
          learner: learner,
        ),
      ),
    );
    await _reload();
    if (plan == null || !mounted) {
      return;
    }
    final next = [..._plans, plan]
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    await _storePlans(next);
    if (!mounted) {
      return;
    }
    setState(() => _tab = 1);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已加入学习计划 · ${plan.depth.label}'),
        backgroundColor: paperInk,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 换年龄档：年龄选择页保存后回来重读设置。
  Future<void> _changeBand() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => AgeSetupPage(
          store: widget.store,
          onChosen: (band) {
            Navigator.of(routeContext).pop();
          },
        ),
      ),
    );
    final profile = await widget.store.load();
    if (!mounted) {
      return;
    }
    setState(() => _profile = profile);
    await _reload();
  }

  Future<void> _guardian() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GuardianPage(archive: widget.archive),
      ),
    );
    await _reload();
  }

  Future<void> _export() async {
    final file = await widget.archive.exportCopy();
    if (!mounted) {
      return;
    }
    setState(() => _exportPath = file.path);
  }

  /// 读取本机计划，读完顺手检查有没有到点的。
  Future<void> _loadPlans() async {
    final plans = await widget.planStore.load();
    if (!mounted) {
      return;
    }
    setState(() => _plans = plans);
    await _checkPlanReminder();
  }

  /// 把新的计划列表写入本机并刷新界面。
  Future<void> _storePlans(List<StudyPlan> plans) async {
    await widget.planStore.save(plans);
    if (!mounted) {
      return;
    }
    setState(() => _plans = plans);
  }

  /// 到点的计划弹一次提醒；提醒过的写进本机，避免每次打开都再弹。
  ///
  /// 弹窗关掉后再写入：选「稍后」推迟 10 分钟，选「现在开始」记为已提醒。
  Future<void> _checkPlanReminder() async {
    if (_reminderOpen || !mounted) {
      return;
    }
    final now = DateTime.now();
    StudyPlan? due;
    for (final plan in _plans) {
      if (plan.done || !plan.remind || plan.remindedAt != null) {
        continue;
      }
      if (plan.snoozedUntil != null && plan.snoozedUntil!.isAfter(now)) {
        continue;
      }
      if (plan.startAt.isAfter(now)) {
        continue;
      }
      due = plan;
      break;
    }
    if (due == null) {
      return;
    }
    final target = due;
    final domain = widget.graph.domainById(target.domainId);
    _reminderOpen = true;
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: paperSurface,
        title: const Text('计划到时间了'),
        content: Text(
          '${domain?.name ?? '学习'} · ${target.depth.label}\n现在开始吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('snooze'),
            child: const Text('稍后'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('start'),
            child: const Text('现在开始'),
          ),
        ],
      ),
    );
    _reminderOpen = false;
    if (!mounted) {
      return;
    }
    // 点空白关掉也算「稍后」，不丢提醒也不算已经提醒过。
    final startNow = choice == 'start';
    final marked = [
      for (final plan in _plans)
        plan.id == target.id
            ? (startNow
                ? plan.copyWith(remindedAt: now)
                : plan.copyWith(
                    snoozedUntil: now.add(const Duration(minutes: 10)),
                  ))
            : plan,
    ];
    await _storePlans(marked);
    if (!mounted) {
      return;
    }
    if (startNow && domain != null) {
      await _openPlan(target, domain);
    }
  }

  /// 进入计划对应的领域阶梯；简单了解只看前两层。
  Future<void> _openPlan(StudyPlan plan, LearningDomain domain) async {
    final band = _profile.band;
    if (band == null) {
      return;
    }
    final next = _profile.withFocus(domain.id);
    await widget.store.save(next);
    if (!mounted) {
      return;
    }
    setState(() => _profile = next);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DomainPage(
          archive: widget.archive,
          band: band,
          domain: domain,
          graph: widget.graph,
          maxDepth: plan.depth.maxDepth,
          onFinish: () => _openReview(plan, domain),
        ),
      ),
    );
    await _reload();
  }

  /// 学完之后的小测；通过就再把计划标成完成，并回到首页。
  Future<void> _openReview(StudyPlan plan, LearningDomain domain) async {
    final band = _profile.band;
    if (band == null) {
      return;
    }
    final passed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ReviewPage(
          archive: widget.archive,
          band: band,
          domain: domain,
          maxDepth: plan.depth.maxDepth,
        ),
      ),
    );
    await _reload();
    if (!mounted || passed != true) {
      return;
    }
    await _markPlanDone(plan);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  /// 把一条计划标成已完成，不来回切换。
  Future<void> _markPlanDone(StudyPlan plan) async {
    final next = [
      for (final item in _plans)
        item.id == plan.id ? item.copyWith(done: true) : item,
    ];
    await _storePlans(next);
  }

  /// 新建一条计划：编辑器返回后写进本机。
  Future<void> _addPlan() async {
    final band = _profile.band;
    if (band == null) {
      return;
    }
    final plan = await Navigator.of(context).push<StudyPlan>(
      MaterialPageRoute<StudyPlan>(
        builder: (_) => PlanEditorPage(graph: widget.graph, band: band),
      ),
    );
    if (plan == null || !mounted) {
      return;
    }
    final next = [..._plans, plan]
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    await _storePlans(next);
  }

  /// 标记完成或取消完成。
  Future<void> _togglePlanDone(StudyPlan plan) async {
    final next = [
      for (final item in _plans)
        item.id == plan.id ? item.copyWith(done: !item.done) : item,
    ];
    await _storePlans(next);
  }

  /// 删除一条计划前再确认一次，避免误触。
  Future<void> _deletePlan(StudyPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: paperSurface,
        title: const Text('删除这条计划？'),
        content: Text(
          '${widget.graph.domainById(plan.domainId)?.name ?? '学习'} · '
          '${plan.depth.label}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('留着'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final next = _plans.where((item) => item.id != plan.id).toList();
    await _storePlans(next);
  }

  /// 当前入口对应的视图；只构建当前这一页，避免隐藏页面重复占位。
  Widget _currentView(AgeBand band, LearnerState learner) {
    return switch (_tab) {
      1 => LearnView(
          graph: widget.graph,
          band: band,
          learner: learner,
          focusDomainId: _profile.focusDomainId,
          recordCount: _recordCount,
          plans: _plans,
          showDonePlans: _showDonePlans,
          onToggleDonePlans: () =>
              setState(() => _showDonePlans = !_showDonePlans),
          onOpenToday: _openConcept,
          onAddPlan: _addPlan,
          onOpenPlan: (plan) {
            final domain = widget.graph.domainById(plan.domainId);
            if (domain != null) {
              _openPlan(plan, domain);
            }
          },
          onToggleDone: _togglePlanDone,
          onDeletePlan: _deletePlan,
          onChangeBand: _changeBand,
        ),
      2 => ProfileView(
          graph: widget.graph,
          band: band,
          learner: learner,
          plans: _plans,
          recordCount: _recordCount,
          exportPath: _exportPath,
          onChangeBand: _changeBand,
          onGuardian: _guardian,
          onExport: _export,
        ),
      _ => LibraryView(
          graph: widget.graph,
          band: band,
          learner: learner,
          tab: _libraryTab,
          onSelectTab: (index) => setState(() => _libraryTab = index),
          onOpen: _openKnowledge,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final band = _profile.band;
    final learner = _learner;
    if (band == null) {
      return Scaffold(
        body: Center(
          child: Text('还没有选择年龄档。', style: Theme.of(context).textTheme.bodyMedium),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppBrand.name),
            const SizedBox(width: 6),
            Text(
              AppBrand.englishName,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(letterSpacing: 2, color: paperInkSoft),
            ),
          ],
        ),
      ),
      body: learner == null
          ? const Center(
              child: CircularProgressIndicator(color: paperOchre),
            )
          : SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  // 进入时淡入并轻轻往上抬，像翻过一页纸。
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.02),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey<int>(_tab),
                  child: _currentView(band, learner),
                ),
              ),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            label: '知识库',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            label: '学习',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
