import 'package:flutter/material.dart';

import '../app_brand.dart';
import '../archive/archive_store.dart';
import '../archive/learning_record.dart';
import '../data/auth_session.dart';
import '../data/study_repository.dart';
import '../guardian/guardian_page.dart';
import '../knowledge/age_band.dart';
import '../knowledge/concept.dart';
import '../knowledge/knowledge_graph.dart';
import '../knowledge/taxonomy.dart';
import '../learning/learner_state.dart';
import '../messages/app_message.dart';
import '../messages/message_read_store.dart';
import '../plan/plan_book.dart';
import '../plan/plan_store.dart';
import '../plan/study_plan.dart';
import '../profile/profile_store.dart';
import '../profile/study_profile.dart';
import 'age_setup_page.dart';
import 'add_knowledge_dialog.dart';
import 'add_subtype_dialog.dart';
import 'category_page.dart';
import 'edit_category_dialog.dart';
import 'concept_page.dart';
import 'feedback.dart';
import 'knowledge_detail_page.dart';
import 'learn_view.dart';
import 'library_view.dart';
import 'plan_editor_page.dart';
import 'plan_view.dart';
import 'profile_view.dart';
import 'review_page.dart';
import 'sage_page.dart';
import 'theme.dart';
import 'widgets/app_mark.dart';
import 'widgets/knowledge_search_bar.dart';
import 'widgets/message_menu_button.dart';
import 'widgets/plan_reminder.dart';

/// 首页：规划、知识库、学习、我的四个入口。
///
/// 规划管什么时候学什么；知识库按程度和分类看全部知识；
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

  /// 知识库停在树的哪个分类节点上，返回后保持不动。
  String? _librarySelection;

  /// 知识库当前展开的类 id。
  ///
  /// 左侧树是手风琴模式：同一时间只展开一条分支，点开新分支会收起其他分支。
  Set<String> _libraryExpanded = <String>{};

  /// 当前知识图谱；在知识库添加子类/知识后换成刷新后的版本。
  late KnowledgeGraph _graph = widget.graph;

  String? _exportPath;

  /// 最近一次加载的档案记录，供「我的」页展示最近学习与成就。
  List<LearningRecord> _records = const <LearningRecord>[];

  /// 已读消息 id；持久化到本机文件，重启后不再重复提醒。
  final MessageReadStore _readStore = FileMessageReadStore();
  Set<String> _readMessageIds = <String>{};

  /// 本次启动时间，用来给系统通知一个稳定的时间。
  late final DateTime _sessionStartedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _book.addListener(_onPlansChanged);
    _book.load();
    _readStore.load().then((ids) {
      if (mounted) {
        setState(() => _readMessageIds = ids);
      }
    });
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
      _records = archive.records;
    });
  }

  /// 重新拉取知识库；成功后换图谱，失败返回原因（成功返回 null）。
  Future<String?> _refreshKnowledge() async {
    try {
      final catalog = await widget.repository.reloadKnowledge();
      if (!mounted) {
        return null;
      }
      setState(() => _graph = catalog.graph);
      return null;
    } catch (error) {
      return '$error';
    }
  }

  /// 某个分类的祖先 id 集合，用来展开左侧树。
  ///
  /// 选中或新建深层子类时，把整条祖先链都展开，避免新节点藏在收起的父级里。
  Set<String> _ancestorIds(ScholarCategory category) {
    final ids = <String>{};
    var parentId = category.parentId;
    while (parentId != null) {
      ids.add(parentId);
      parentId = _graph.categoryById(parentId)?.parentId;
    }
    return ids;
  }

  /// childId 是否是 ancestorId 的后代。
  ///
  /// 收起某个分类时，用它一并收起已经展开的子孙，避免留下悬空的展开状态。
  bool _isDescendantOf(String childId, String ancestorId) {
    var parentId = _graph.categoryById(childId)?.parentId;
    while (parentId != null) {
      if (parentId == ancestorId) {
        return true;
      }
      parentId = _graph.categoryById(parentId)?.parentId;
    }
    return false;
  }

  /// 点击分类卡片：选中它，并把左侧树切到它所在的那一条展开链。
  ///
  /// 手风琴模式会收起其他分支；当前分类若本来就是展开的，则保持它的子级可见。
  void _selectLibraryCategory(ScholarCategory category) {
    setState(() {
      _librarySelection = category.id;
      final expanded = _ancestorIds(category);
      if (_libraryExpanded.contains(category.id)) {
        expanded.add(category.id);
      }
      _libraryExpanded = expanded;
    });
  }

  /// 展开 / 收起某个分类：展开时只保留这一条分支，其他分支全部收起。
  void _toggleLibraryExpanded(ScholarCategory category) {
    setState(() {
      if (_libraryExpanded.contains(category.id)) {
        _libraryExpanded = {
          for (final id in _libraryExpanded)
            if (id != category.id && !_isDescendantOf(id, category.id)) id,
        };
        return;
      }
      // 手风琴：祖先链保证可见，其余展开的分支全部让位。
      _libraryExpanded = {..._ancestorIds(category), category.id};
    });
  }

  /// 非管理员拦截知识内容编辑；返回 true 表示放行。
  bool _requireAdminForEdit() {
    if (AuthSession.isAdmin) {
      return true;
    }
    showInfoToast(context, '普通用户只读，请先用管理员账号在「我的」页登录。');
    return false;
  }

  /// 知识库「+ 子类型」：在当前分类下再挂一层子类型，并展开父级、选中新节点。
  Future<void> _addSubtype(ScholarCategory parent) async {
    if (!_requireAdminForEdit()) {
      return;
    }
    final createdId = await showDialog<String>(
      context: context,
      builder: (_) => AddSubtypeDialog(
        repository: widget.repository,
        parent: parent,
        graph: _graph,
      ),
    );
    if (createdId == null || !mounted) {
      return;
    }
    final refreshError = await _refreshKnowledge();
    if (!mounted) {
      return;
    }
    // 弹窗里可以改父类，所以按回读到的真实父链展开，而不是按打开时的分类。
    final created = _graph.categoryById(createdId);
    setState(() {
      _librarySelection = createdId;
      // 手风琴：只保留新子类所在的那一条展开链。
      _libraryExpanded = created != null
          ? _ancestorIds(created)
          : {..._ancestorIds(parent), parent.id};
    });
    if (refreshError != null) {
      await showFailureDialog(
        context,
        title: '子类型已添加，但目录刷新失败',
        reason: '$refreshError\n\n重启应用后即可看到新子类型。',
      );
      return;
    }
    showSuccessToast(context, '子类型已添加');
  }

  /// 知识库「铅笔」：修改当前分类的名称与描述，成功后重新拉取知识库。
  Future<void> _editCategory(ScholarCategory category) async {
    if (!_requireAdminForEdit()) {
      return;
    }
    final parentId = category.parentId;
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => EditCategoryDialog(
        repository: widget.repository,
        category: category,
        parentName:
            parentId == null ? null : _graph.categoryById(parentId)?.name,
      ),
    );
    if (updated != true || !mounted) {
      return;
    }
    final refreshError = await _refreshKnowledge();
    if (!mounted) {
      return;
    }
    if (refreshError != null) {
      await showFailureDialog(
        context,
        title: '分类已修改，但目录刷新失败',
        reason: '$refreshError\n\n重启应用后即可看到新信息。',
      );
      return;
    }
    showSuccessToast(context, '分类信息已更新');
  }

  /// 知识库「+ 知识」：弹窗提交后刷新目录，停留在当前分类。
  Future<void> _addKnowledge(ScholarCategory category) async {
    if (!_requireAdminForEdit()) {
      return;
    }
    final band = _profile.band;
    if (band == null) {
      return;
    }
    // 包含新建但还没有知识的空子类，方便把第一条知识加进去。
    final categories = _graph.categories;
    if (categories.isEmpty) {
      showInfoToast(context, '还没有分类，先添加一个子类吧。');
      return;
    }
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => AddKnowledgeDialog(
        repository: widget.repository,
        band: band,
        categories: categories,
        initialCategory: _initialCategoryIn(category),
      ),
    );
    if (created != true || !mounted) {
      return;
    }
    final refreshError = await _refreshKnowledge();
    if (!mounted) {
      return;
    }
    if (refreshError != null) {
      await showFailureDialog(
        context,
        title: '知识已添加，但目录刷新失败',
        reason: '$refreshError\n\n重启应用后即可看到新知识。',
      );
      return;
    }
    showSuccessToast(context, '知识已添加');
  }

  /// 新知识默认落到的分类：优先当前选中/传入的分类，再退回其子树里的第一个。
  ScholarCategory _initialCategoryIn(ScholarCategory category) {
    final selection = _librarySelection;
    if (selection != null) {
      final selected = _graph.categoryById(selection);
      if (selected != null) {
        return selected;
      }
    }
    final under = _graph.categoriesUnder(category);
    return under.isNotEmpty ? under.first : category;
  }

  /// 汇总当前消息：系统欢迎 + 还没完成的计划提醒。
  ///
  /// 消息暂时按界面即时生成，不额外落库；后续接推送时再换存储。
  List<AppMessage> _buildMessages(AgeBand band) {
    final messages = <AppMessage>[
      AppMessage(
        id: 'system_welcome',
        kind: AppMessageKind.system,
        title: '欢迎回到文明重启',
        body: '顶部搜索框可以直接找知识；分类、知识与知识点都在知识库里维护。',
        createdAt: _sessionStartedAt,
      ),
    ];
    for (final plan in _book.plans) {
      if (plan.done) {
        continue;
      }
      final category = _graph.categoryById(plan.categoryId);
      final concept =
          plan.conceptId == null ? null : _graph.conceptById(plan.conceptId!);
      final topic = concept != null && concept.availableIn(band)
          ? concept.variantFor(band).topic
          : null;
      final body = topic != null
          ? '${category?.displayNameFor(band) ?? '知识'} · $topic'
          : '${category?.displayNameFor(band) ?? '分类'} 的阶梯在等你，点开就能继续。';
      messages.add(
        AppMessage(
          id: 'plan_${plan.id}',
          kind: AppMessageKind.planReminder,
          title: '计划到时间了 · ${plan.degree?.label ?? '分类学习'}',
          body: body,
          createdAt: plan.startAt,
          // 计划提醒需要处理，消息末尾给一个直达规划页的按钮。
          actionLabel: '去计划',
        ),
      );
    }
    messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return messages;
  }

  /// 顶部消息角标上的未读数。
  /// 点消息上的操作按钮：计划提醒直接切到「规划」页。
  ///
  /// 消息本身已在组件里记为已读，这里只负责页面跳转。
  void _handleMessageAction(AppMessage message) {
    if (!mounted) {
      return;
    }
    setState(() {
      if (message.kind == AppMessageKind.planReminder) {
        _tab = 0;
      }
    });
  }

  /// 进入某一步学习；回来后重新读档案。
  Future<void> _openConcept(Concept concept, ScholarCategory category) async {
    final band = _profile.band;
    if (band == null) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConceptPage(
          archive: widget.archive,
          band: band,
          category: category,
          concept: concept,
        ),
      ),
    );
    await _reload();
  }

  /// 打开一条知识的详情；在详情里按程度加入计划后写进计划簿。
  Future<void> _openKnowledge(Concept concept, ScholarCategory category) async {
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
          graph: _graph,
          band: band,
          category: category,
          concept: concept,
          learner: learner,
          plans: _book.plans,
          // 成功提示由详情页统一给出，这里只负责写计划簿，避免重复提示。
          onAddPlan: _book.add,
        ),
      ),
    );
    await _reload();
    // 详情页里可能刚加过知识点或章节，回到库页时再拉一次，保证展示的是数据库最新内容。
    await _refreshKnowledge();
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

  /// 进入智者页：填署名、审核纠错、查看自己的贡献。
  /// 回来后刷新目录，因为智者页里可能新建了分类或提交了知识。
  Future<void> _sage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SagePage(
          repository: widget.repository,
          store: widget.store,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    final refreshError = await _refreshKnowledge();
    if (refreshError != null && mounted) {
      await showFailureDialog(
        context,
        title: '知识库刷新失败',
        reason: refreshError,
      );
    }
  }

  Future<void> _export() async {
    final file = await widget.archive.exportCopy();
    if (!mounted) {
      return;
    }
    setState(() => _exportPath = file.path);
  }

  /// 导入档案：先列出导出副本，确认后整份替换当前档案。
  Future<void> _import() async {
    final copies = await widget.archive.listExportedCopies();
    if (!mounted) {
      return;
    }
    if (copies.isEmpty) {
      showInfoToast(context, '还没有导出副本，先用「导出档案到本地」导出一份。');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('import_archive_dialog'),
        title: const Text('导入档案'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('选择要导入的副本（导入会覆盖当前档案）：'),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: copies.length,
                  itemBuilder: (context, index) {
                    final name = copies[index].uri.pathSegments.last;
                    return ListTile(
                      dense: true,
                      title: Text(name, overflow: TextOverflow.ellipsis),
                      onTap: () => Navigator.of(ctx).pop(true),
                      trailing: index == 0 ? const Text('最新') : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      final archive = await widget.archive.importCopy(copies.first);
      if (!mounted) {
        return;
      }
      setState(() {
        _learner = LearnerState.fromRecords(archive.records);
        _recordCount = archive.records.length;
      });
      showSuccessToast(context, '档案已导入：${archive.records.length} 条记录');
    } catch (error) {
      if (!mounted) {
        return;
      }
      await showFailureDialog(context, title: '档案导入失败', reason: '$error');
    }
  }

  /// 进入计划对应的分类阶梯；简单了解只看前两层。
  Future<void> _openPlan(StudyPlan plan, ScholarCategory category) async {
    final band = _profile.band;
    if (band == null) {
      return;
    }
    final next = _profile.withFocus(category.id);
    await widget.store.save(next);
    if (!mounted) {
      return;
    }
    setState(() => _profile = next);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CategoryPage(
          archive: widget.archive,
          band: band,
          category: category,
          graph: _graph,
          maxDepth: plan.depth.maxDepth,
          onFinish: () => _openReview(plan, category),
        ),
      ),
    );
    await _reload();
  }

  /// 学完之后的小测；通过就再把计划标成完成，并回到首页。
  Future<void> _openReview(StudyPlan plan, ScholarCategory category) async {
    final band = _profile.band;
    if (band == null) {
      return;
    }
    final passed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ReviewPage(
          archive: widget.archive,
          band: band,
          category: category,
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
        builder: (_) => PlanEditorPage(graph: _graph, band: band),
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
    ScholarCategory category,
  ) async {
    final now = DateTime.now();
    await _book.add(
      StudyPlan(
        id: 'plan_${now.microsecondsSinceEpoch}',
        categoryId: category.id,
        depth: PlanDepth.deep,
        conceptId: concept.id,
        degree: widget.repository.catalog.degrees.first,
        startAt: now,
        remind: false,
      ),
    );
  }

  /// 当前入口对应的视图；只构建当前这一页，避免隐藏页面重复占位。
  Widget _currentView(AgeBand band, LearnerState learner) {
    return switch (_tab) {
      1 => LibraryView(
          graph: _graph,
          band: band,
          learner: learner,
          selection: _librarySelection,
          expandedIds: _libraryExpanded,
          onSelectCategory: _selectLibraryCategory,
          onToggleExpand: _toggleLibraryExpanded,
          onOpen: _openKnowledge,
          onAddSubtype: _addSubtype,
          onAddKnowledge: _addKnowledge,
          onEditCategory: _editCategory,
        ),
      2 => LearnView(
          graph: _graph,
          band: band,
          learner: learner,
          focusCategoryId: _profile.focusCategoryId,
          recordCount: _recordCount,
          plans: _book.plans,
          onOpenToday: _openConcept,
          onOpenPlan: (plan) {
            final category = _graph.categoryById(plan.categoryId);
            if (category != null) {
              _openPlan(plan, category);
            }
          },
          onGoPlan: () => setState(() => _tab = 0),
          onAddPlan: _addPlan,
          onChangeBand: _changeBand,
        ),
      3 => ProfileView(
            repository: widget.repository,
            graph: _graph,
          band: band,
          learner: learner,
          plans: _book.plans,
          recordCount: _recordCount,
          exportPath: _exportPath,
          records: _records,
          onChangeBand: _changeBand,
          onGuardian: _guardian,
          onExport: _export,
          onImport: _import,
          onSage: _sage,
        ),
      _ => PlanView(
          archive: widget.archive,
          graph: _graph,
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
        centerTitle: false,
        titleSpacing: 16,
        title: Row(
          children: [
            Tooltip(
              message: '${AppBrand.name} ${AppBrand.englishName}',
              child: const AppMark(size: 34),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: KnowledgeSearchBar(
                graph: _graph,
                band: band,
                onOpen: _openKnowledge,
              ),
            ),
          ],
        ),
        actions: [
          MessageMenuButton(
            messages: _buildMessages(band),
            readIds: _readMessageIds,
            onMarkRead: (id) {
              setState(() => _readMessageIds.add(id));
              _readStore.save(_readMessageIds);
            },
            onMarkAllRead: () {
              setState(() {
                _readMessageIds.addAll(
                  _buildMessages(band).map((message) => message.id),
                );
              });
              _readStore.save(_readMessageIds);
            },
            onAction: _handleMessageAction,
          ),
          const SizedBox(width: 8),
        ],
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
              graph: _graph,
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
