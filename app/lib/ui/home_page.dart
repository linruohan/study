import 'package:flutter/material.dart';

import '../app_brand.dart';
import '../archive/archive_store.dart';
import '../data/study_repository.dart';
import '../guardian/guardian_page.dart';
import '../knowledge/age_band.dart';
import '../knowledge/concept.dart';
import '../knowledge/domain.dart';
import '../knowledge/knowledge_catalog.dart';
import '../knowledge/knowledge_graph.dart';
import '../learning/learner_state.dart';
import '../plan/plan_book.dart';
import '../plan/plan_store.dart';
import '../plan/study_plan.dart';
import '../profile/profile_store.dart';
import '../profile/study_profile.dart';
import 'age_setup_page.dart';
import 'concept_page.dart';
import 'domain_page.dart';
import 'knowledge_detail_page.dart';
import 'learn_view.dart';
import 'library_view.dart';
import 'plan_editor_page.dart';
import 'plan_view.dart';
import 'profile_view.dart';
import 'review_page.dart';
import 'sage_page.dart';
import 'theme.dart';
import 'widgets/plan_reminder.dart';

/// 首页：规划、知识库、学习、我的四个入口。
///
/// 规划管什么时候学什么；知识库按程度和领域看全部知识；
/// 学习只放今日一步和下一条计划；我的放等级、徽章和设置。
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.archive,
    required this.store,
    required this.planStore,
    required this.profile,
    required this.graph,
    required this.repository,
  });

  final ArchiveStore archive;
  final ProfileStore store;
  final PlanStore planStore;
  final StudyProfile profile;
  final KnowledgeGraph graph;
  final StudyRepository repository;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late StudyProfile _profile = widget.profile;
  late final PlanBook _book = PlanBook(widget.planStore);
  LearnerState? _learner;
  var _recordCount = 0;
  var _tab = 0;

  /// 知识库停在树的哪个节点（类 id 或领域 id），返回后保持不动。
  String? _librarySelection;

  /// 知识库当前展开的类 id；null 表示全部收起。
  Set<String> _libraryExpanded = <String>{};

  String? _exportPath;

  @override
  void initState() {
    super.initState();
    _book.addListener(_onPlansChanged);
    _book.load();
    _reload();
  }

  @override
  void dispose() {
    _book.removeListener(_onPlansChanged);
    _book.dispose();
    super.dispose();
  }

  /// 计划一变就重画：计数、列表和底部角标都跟着更新。
  void _onPlansChanged() {
    if (mounted) {
      setState(() {});
    }
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

  /// 打开一条知识的详情；在详情里按程度加入计划后写进计划簿。
  Future<void> _openKnowledge(Concept concept, LearningDomain domain) async {
    final band = _profile.band;
    final learner = _learner;
    if (band == null || learner == null) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => KnowledgeDetailPage(
          archive: widget.archive,
          repository: widget.repository,
          graph: widget.graph,
          band: band,
          domain: domain,
          concept: concept,
          learner: learner,
          plans: _book.plans,
          onAddPlan: (plan) {
            _book.add(plan);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已加入计划 · ${plan.degree?.label ?? ''}')),
              );
            }
          },
        ),
      ),
    );
    await _reload();
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

  /// 进入智者页：填名字、提交知识或知识点、看自己的贡献。
  Future<void> _sage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SagePage(
          repository: widget.repository,
          store: widget.store,
        ),
      ),
    );
  }

  Future<void> _export() async {
    final file = await widget.archive.exportCopy();
    if (!mounted) {
      return;
    }
    setState(() => _exportPath = file.path);
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
    await _book.markDone(plan);
    if (mounted) {
      Navigator.of(context).pop();
    }
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
    await _book.add(plan);
  }

  /// 删除一条知识计划；规划页的卡片菜单用。
  Future<void> _deletePlan(StudyPlan plan) async {
    await _book.remove(plan);
  }

  /// 在规划页把一条没排进计划的知识按入门程度排进来。
  Future<void> _addConceptPlan(
    Concept concept,
    LearningDomain domain,
  ) async {
    final now = DateTime.now();
    await _book.add(
      StudyPlan(
        id: 'plan_${now.microsecondsSinceEpoch}',
        domainId: domain.id,
        depth: PlanDepth.deep,
        conceptId: concept.id,
        degree: KnowledgeCatalog.instance.degrees.first,
        startAt: now,
        remind: false,
      ),
    );
  }

  /// 当前入口对应的视图；只构建当前这一页，避免隐藏页面重复占位。
  Widget _currentView(AgeBand band, LearnerState learner) {
    return switch (_tab) {
      1 => LibraryView(
          graph: widget.graph,
          band: band,
          learner: learner,
          selection: _librarySelection,
          expandedIds: _libraryExpanded,
          onSelectCategory: (category) =>
              setState(() => _librarySelection = category.id),
          onToggleExpand: (category) => setState(() {
            if (_libraryExpanded.contains(category.id)) {
              _libraryExpanded = {..._libraryExpanded}..remove(category.id);
            } else {
              _libraryExpanded = {..._libraryExpanded, category.id};
            }
          }),
          onSelectDomain: (domain) =>
              setState(() => _librarySelection = domain.id),
          onOpen: _openKnowledge,
        ),
      2 => LearnView(
          graph: widget.graph,
          band: band,
          learner: learner,
          focusDomainId: _profile.focusDomainId,
          recordCount: _recordCount,
          plans: _book.plans,
          onOpenToday: _openConcept,
          onOpenPlan: (plan) {
            final domain = widget.graph.domainById(plan.domainId);
            if (domain != null) {
              _openPlan(plan, domain);
            }
          },
          onGoPlan: () => setState(() => _tab = 0),
          onAddPlan: _addPlan,
          onChangeBand: _changeBand,
        ),
      3 => ProfileView(
          graph: widget.graph,
          band: band,
          learner: learner,
          plans: _book.plans,
          recordCount: _recordCount,
          exportPath: _exportPath,
          onChangeBand: _changeBand,
          onGuardian: _guardian,
          onExport: _export,
          onSage: _sage,
        ),
      _ => PlanView(
          archive: widget.archive,
          graph: widget.graph,
          band: band,
          learner: learner,
          plans: _book.plans,
          onDeleted: _deletePlan,
          onAddConceptPlan: _addConceptPlan,
          onReload: _reload,
        ),
    };
  }

  /// 「规划」图标：有到点该提醒的计划时，挂一个小圆点。
  Widget _planIcon(IconData icon) {
    final due = _book.firstDue(DateTime.now()) != null;
    return Badge(
      isLabelVisible: due,
      backgroundColor: paperOchre,
      smallSize: 7,
      child: Icon(icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    final band = _profile.band;
    final learner = _learner;
    if (band == null) {
      return Scaffold(
        body: Center(
          child: Text(
            '还没有选择年龄档。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
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
        // 一条极细的墨线，把标题区和纸面正文分开。
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: paperLine),
        ),
      ),
      body: learner == null
          ? const Center(
              child: CircularProgressIndicator(color: paperOchre),
            )
          : PlanReminder(
              book: _book,
              graph: widget.graph,
              band: band,
              onStart: _openPlan,
              child: SafeArea(
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
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: [
          NavigationDestination(
            icon: _planIcon(Icons.event_note_outlined),
            label: '规划',
          ),
          const NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            label: '知识库',
          ),
          const NavigationDestination(
            icon: Icon(Icons.school_outlined),
            label: '学习',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
