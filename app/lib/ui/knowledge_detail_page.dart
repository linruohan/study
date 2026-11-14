import 'package:flutter/material.dart';

import '../archive/archive_store.dart';
import '../data/auth_session.dart';
import '../data/study_repository.dart';
import '../knowledge/age_band.dart';
import '../knowledge/concept.dart';
import '../knowledge/taxonomy.dart';
import '../knowledge/knowledge_catalog.dart';
import '../knowledge/knowledge_graph.dart';
import '../knowledge/study_degree.dart';
import '../learning/learner_state.dart';
import '../plan/study_plan.dart';
import 'feedback.dart';
import 'theme.dart';
import 'widgets/glyph_badge.dart';

/// 知识详情页：知识简介、按程度查看知识点与章节，支持加入计划、评论与纠错。
class KnowledgeDetailPage extends StatefulWidget {
  const KnowledgeDetailPage({
    super.key,
    required this.archive,
    required this.repository,
    required this.graph,
    required this.band,
    required this.category,
    required this.concept,
    required this.learner,
    required this.plans,
    required this.onAddPlan,
  });

  final ArchiveStore archive;
  final StudyRepository repository;
  final KnowledgeGraph graph;
  final AgeBand band;
  final ScholarCategory category;
  final Concept concept;

  /// 进入时的学习者状态。
  final LearnerState learner;

  /// 本机全部计划，用来判断这个知识是否已在计划中。
  final List<StudyPlan> plans;

  /// 按当前程度加入计划；由首页写进计划簿。
  final void Function(StudyPlan plan) onAddPlan;

  @override
  State<KnowledgeDetailPage> createState() => _KnowledgeDetailPageState();
}

class _KnowledgeDetailPageState extends State<KnowledgeDetailPage>
    with SingleTickerProviderStateMixin {
  late final LearnerState _learner = widget.learner;
  /// 当前这条知识的最新服务端副本；每次写入后重新拉取并替换。
  late Concept _concept = widget.concept;

  /// 当前年龄档的呈现，始终从 [_concept] 派生，保证展示的就是数据库里的内容。
  ConceptVariant get _variant => _concept.variantFor(widget.band);

  late final TabController _tabs = TabController(
    length: widget.repository.catalog.degrees.length,
    vsync: this,
  )..addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

  StudyDegree get _degree => widget.repository.catalog.degrees[_tabs.index];

  Set<StudyDegree> get _plannedDegrees {
    return {
      for (final plan in widget.plans)
        if (plan.conceptId == widget.concept.id && plan.degree != null)
          plan.degree!,
    };
  }

  String _creatorOfConcept() {
    final catalog = KnowledgeCatalog.maybeInstance;
    if (catalog == null) {
      return '';
    }
    return catalog.sageCredits.creatorOfConcept(widget.concept.id);
  }

  /// 写入成功后重新向服务端要一份知识库，用返回的数据刷新当前页面。
  ///
  /// 页面内容只走「界面提交 → 接口写库 → 接口重新读取 → 页面重绘」这一条链路，
  /// 不在本地拼接新数据，避免界面和数据库不一致。
  Future<void> _refreshConcept() async {
    final catalog = await widget.repository.reloadKnowledge();
    final refreshed = catalog.graph.conceptById(widget.concept.id);
    if (refreshed == null || !refreshed.availableIn(widget.band)) {
      throw StateError('刷新后没找到这条知识，请稍后再试');
    }
    if (!mounted) {
      return;
    }
    setState(() => _concept = refreshed);
  }

  /// 在某个学习程度下追加一个知识点；写库成功后重新读取并刷新页面。
  Future<void> _addPoint(
    BuildContext context,
    StudyDegree degree,
  ) async {
    if (!_requireAdminForEdit(context)) {
      return;
    }
    final controller = TextEditingController();
    var level = 'remember';
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          key: const Key('add_point_dialog'),
          title: Text('添加知识点 · ${degree.label}'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('add_point_text'),
                  controller: controller,
                  autofocus: true,
                  maxLength: 500,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '知识点内容',
                    hintText: '这个程度下要多学的一句',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: level,
                  decoration: const InputDecoration(
                    labelText: '认知层级',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final entry in kCognitiveLevelLabels.entries)
                      DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => level = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              key: const Key('add_point_submit'),
              onPressed: () {
                if (controller.text.trim().isEmpty) {
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
    final point = controller.text.trim();
    controller.dispose();
    if (created != true || point.isEmpty || !mounted) {
      return;
    }
    try {
      await widget.repository.addKnowledgePoint(
        conceptId: widget.concept.id,
        ageBandId: widget.band.id,
        degreeId: degree.id,
        point: point,
        cognitiveLevel: level,
      );
      // 重新从数据库读取，页面显示接口返回的最新知识点。
      await _refreshConcept();
      if (!mounted) {
        return;
      }
      showSuccessToast(this.context, '知识点已添加');
    } catch (error) {
      if (!mounted) {
        return;
      }
      await showFailureDialog(
        this.context,
        title: '知识点添加失败',
        reason: '$error',
      );
    }
  }

  /// 非管理员拦截编辑与审核操作；返回 true 表示放行。
  bool _requireAdminForEdit(BuildContext context) {
    if (AuthSession.isAdmin) {
      return true;
    }
    showInfoToast(context, '普通用户只读，请先用管理员账号在「我的」页登录。');
    return false;
  }

  Future<void> _addChapter(BuildContext context, StudyDegree degree, int position) async {
    if (!_requireAdminForEdit(context)) {
      return;
    }
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加章节'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleController, decoration: const InputDecoration(labelText: '章节标题', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: contentController, maxLines: 3, decoration: const InputDecoration(labelText: '内容（可选）', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final title = titleController.text.trim();
              if (title.isEmpty) return;
              try {
                await widget.repository.createPointChapter(
                  conceptId: widget.concept.id,
                  ageBandId: widget.band.id,
                  degreeId: degree.id,
                  pointPosition: position,
                  title: title,
                  content: contentController.text.trim().isEmpty ? null : contentController.text.trim(),
                );
                if (ctx.mounted) Navigator.of(ctx).pop(true);
              } catch (e) {
                if (!ctx.mounted) return;
                await showFailureDialog(
                  ctx,
                  title: '章节添加失败',
                  reason: '$e',
                );
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
    final ok = created == true;
    titleController.dispose();
    contentController.dispose();
    if (!ok || !mounted) return;
    try {
      // 章节已入库，重新读取整条知识，页面按数据库内容重绘。
      await _refreshConcept();
      if (!mounted) return;
      showSuccessToast(this.context, '章节已添加');
    } catch (error) {
      if (!mounted) return;
      await showFailureDialog(
        this.context,
        title: '章节已添加，但刷新失败',
        reason: '$error',
      );
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _addToPlan() async {
    final degree = _degree;
    if (_plannedDegrees.contains(degree)) {
      showInfoToast(context, '这个知识已在计划里（${degree.label}）');
      return;
    }
    final now = DateTime.now();
    widget.onAddPlan(
      StudyPlan(
        id: 'plan_${now.microsecondsSinceEpoch}',
        categoryId: widget.category.id,
        depth: PlanDepth.deep,
        conceptId: widget.concept.id,
        degree: degree,
        startAt: now,
        remind: false,
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {});
    showSuccessToast(context, '已加入计划 · ${degree.label}');
  }

  @override
  Widget build(BuildContext context) {
    final variant = _variant;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.displayNameFor(widget.band)),
        bottom: TabBar(
          controller: _tabs,
          labelColor: paperOchre,
          unselectedLabelColor: paperInkSoft,
          indicatorColor: paperOchre,
          tabs: [
            for (final degree in widget.repository.catalog.degrees)
              Tab(text: degree.label),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabs,
          children: [
            for (final degree in widget.repository.catalog.degrees)
              _degreeTab(context, degree, variant),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
          child: FilledButton(
            key: const Key('add_to_plan'),
            onPressed: _addToPlan,
            child: Text('把「${_degree.label}」加入我的计划'),
          ),
        ),
      ),
    );
  }

  Widget _degreeTab(
    BuildContext context,
    StudyDegree degree,
    ConceptVariant variant,
  ) {
    final text = Theme.of(context).textTheme;
    final tier = _learner.tierOf(widget.concept.id);
    final practiceCount = _learner.practiceCount(widget.concept.id);
    final planned = _plannedDegrees.contains(degree);
    final creator = _creatorOfConcept();
    final points = variant.pointsFor(degree);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlyphBadge(
              glyph: variant.glyph ?? widget.category.glyph,
              color: widget.category.color,
              size: 56,
              rounded: true,
              fontSize: 26,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(variant.topic, style: text.headlineSmall),
                  const SizedBox(height: 6),
                  Text(variant.note ?? variant.doing, style: text.bodySmall),
                  if (creator.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.auto_stories_outlined,
                            size: 14, color: paperOchre),
                        const SizedBox(width: 4),
                        Text(
                          '智者：$creator',
                          style: text.bodySmall?.copyWith(color: paperOchre),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            MasteryPill(label: '第 ${widget.concept.depth + 1} 层', color: paperStone),
            MasteryPill(
              label: tier?.label ?? '未开始',
              color: tier == null ? paperInkSoft : paperOchre,
            ),
            if (practiceCount > 0)
              MasteryPill(label: '练过 $practiceCount 次', color: paperInkSoft),
            if (planned) MasteryPill(label: '已在计划', color: paperStone),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                '「${degree.label}」要学的知识点',
                style: text.titleMedium,
              ),
            ),
            TextButton.icon(
              key: Key('degree_add_point_${degree.id}'),
              onPressed: () => _addPoint(context, degree),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('添加知识点'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (points.isEmpty)
          Text('这个程度还没有知识点，点右上角添加一条吧。', style: text.bodySmall),
        for (var i = 0; i < points.length; i++) ...[
          _pointCard(context, degree, points[i], i + 1,
              level: variant.levelsFor(degree)[i]),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        Text(
          '加入计划后，可在「规划」页按领域学习。章节是最基础的知识单元；评论与纠错提交后可参与审核与积分。',
          textAlign: TextAlign.center,
          style: text.bodySmall,
        ),
      ],
    );
  }

  Widget _pointCard(
    BuildContext context,
    StudyDegree degree,
    String point,
    int position, {
    String? level,
  }) {
    final text = Theme.of(context).textTheme;
    final chapters = _variant.chaptersFor(degree, position);
    return PaperCard(
      key: Key('point_${degree.id}_${position - 1}'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle_outline, size: 20, color: paperOchre),
              const SizedBox(width: 10),
              Expanded(child: Text(point, style: text.bodyMedium)),
              if (level != null) ...[
                const SizedBox(width: 8),
                MasteryPill(
                  label: cognitiveLevelLabel(level),
                  color: paperStone,
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('章节', style: text.labelMedium?.copyWith(color: paperInkSoft)),
              const Spacer(),
              TextButton.icon(
                key: Key('point_add_chapter_${degree.id}_${position - 1}'),
                onPressed: () => _addChapter(context, degree, position),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('添加章节'),
              ),
            ],
          ),
          if (chapters.isEmpty)
            Text('暂无章节，可添加最基础知识单元。', style: text.bodySmall)
          else ...[
            const SizedBox(height: 6),
            for (var c = 0; c < chapters.length; c++) ...[
              _chapterTile(context, degree, position, chapters[c], c + 1),
              if (c != chapters.length - 1) const SizedBox(height: 6),
            ],
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: Key('point_comments_${degree.id}_${position - 1}'),
                onPressed: () => _openComments(context, degree, point, position),
                icon: const Icon(Icons.chat_bubble_outline, size: 16),
                label: const Text('评论'),
              ),
              OutlinedButton.icon(
                key: Key('point_correction_${degree.id}_${position - 1}'),
                onPressed: () => _openCorrections(context, degree, point, position),
                icon: const Icon(Icons.edit_note_outlined, size: 16),
                label: const Text('纠错/审核'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chapterTile(BuildContext context, StudyDegree degree, int pointPosition, KnowledgeChapter chapter, int index) {
    final text = Theme.of(context).textTheme;
    final content = chapter.content?.trim();
    final chapterPos = chapter.position ?? index;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: paperOchre.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: paperLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text('$index. ${chapter.title}', style: text.bodySmall?.copyWith(color: paperInk))),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                iconSize: 18,
                onSelected: (v) {
                  if (v == 'edit') _editChapter(context, degree, pointPosition, chapter, chapterPos);
                  if (v == 'delete') _deleteChapter(context, degree, pointPosition, chapterPos);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('编辑')),
                  PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              ),
            ],
          ),
          if (content != null && content.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(content, style: text.bodySmall),
          ],
        ],
      ),
    );
  }

  Future<void> _editChapter(BuildContext context, StudyDegree degree, int pointPosition, KnowledgeChapter chapter, int chapterPosition) async {
    if (!_requireAdminForEdit(context)) {
      return;
    }
    final titleController = TextEditingController(text: chapter.title);
    final contentController = TextEditingController(text: chapter.content ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑章节'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleController, decoration: const InputDecoration(labelText: '章节标题', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: contentController, maxLines: 3, decoration: const InputDecoration(labelText: '内容（可选）', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final title = titleController.text.trim();
              if (title.isEmpty) return;
              try {
                await widget.repository.updatePointChapter(
                  conceptId: widget.concept.id,
                  ageBandId: widget.band.id,
                  degreeId: degree.id,
                  pointPosition: pointPosition,
                  chapterPosition: chapterPosition,
                  title: title,
                  content: contentController.text.trim().isEmpty ? null : contentController.text.trim(),
                );
                if (ctx.mounted) Navigator.of(ctx).pop(true);
              } catch (e) {
                if (ctx.mounted) {
                  await showFailureDialog(
                    ctx,
                    title: '章节保存失败',
                    reason: '$e',
                  );
                }
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    titleController.dispose();
    contentController.dispose();
    if (ok != true || !mounted) return;
    try {
      await _refreshConcept();
      if (!mounted) return;
      showSuccessToast(this.context, '章节已更新');
    } catch (e) {
      if (!mounted) return;
      await showFailureDialog(this.context, title: '章节刷新失败', reason: '$e');
    }
  }

  Future<void> _deleteChapter(BuildContext context, StudyDegree degree, int pointPosition, int chapterPosition) async {
    if (!_requireAdminForEdit(context)) {
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除章节'),
        content: const Text('删除后将重排后续章节序号，确定删除吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.repository.deletePointChapter(
        conceptId: widget.concept.id,
        ageBandId: widget.band.id,
        degreeId: degree.id,
        pointPosition: pointPosition,
        chapterPosition: chapterPosition,
      );
      await _refreshConcept();
      if (!mounted) return;
      showSuccessToast(this.context, '章节已删除');
    } catch (e) {
      if (!mounted) return;
      await showFailureDialog(this.context, title: '章节删除失败', reason: '$e');
    }
  }

  Future<void> _openComments(BuildContext context, StudyDegree degree, String point, int position) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _PointCommentsSheet(
        repository: widget.repository,
        band: widget.band,
        concept: widget.concept,
        degree: degree,
        position: position,
        pointText: point,
      ),
    );
  }

  Future<void> _openCorrections(BuildContext context, StudyDegree degree, String point, int position) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _PointCorrectionsSheet(
        repository: widget.repository,
        band: widget.band,
        concept: widget.concept,
        degree: degree,
        position: position,
        pointText: point,
      ),
    );
  }
}

class _PointCommentsSheet extends StatefulWidget {
  const _PointCommentsSheet({
    required this.repository,
    required this.band,
    required this.concept,
    required this.degree,
    required this.position,
    required this.pointText,
  });

  final StudyRepository repository;
  final AgeBand band;
  final Concept concept;
  final StudyDegree degree;
  final int position;
  final String pointText;

  @override
  State<_PointCommentsSheet> createState() => _PointCommentsSheetState();
}

class _PointCommentsSheetState extends State<_PointCommentsSheet> {
  late Future<List<Map<String, dynamic>>> _future;
  final _controller = TextEditingController();
  var _sending = false;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.fetchPointComments(
      conceptId: widget.concept.id,
      ageBandId: widget.band.id,
      degreeId: widget.degree.id,
      position: widget.position,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _future = widget.repository.fetchPointComments(
        conceptId: widget.concept.id,
        ageBandId: widget.band.id,
        degreeId: widget.degree.id,
        position: widget.position,
      );
    });
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.repository.createPointComment(
        conceptId: widget.concept.id,
        ageBandId: widget.band.id,
        degreeId: widget.degree.id,
        position: widget.position,
        body: body,
      );
      _controller.clear();
      await _reload();
    } catch (e) {
      if (mounted) {
        await showFailureDialog(context, title: '评论发送失败', reason: '$e');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('知识点评论', style: text.titleMedium),
              const SizedBox(height: 4),
              Text(widget.pointText, style: text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: paperOchre));
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('加载失败：${snapshot.error}', style: text.bodySmall));
                    }
                    final items = snapshot.data ?? const [];
                    if (items.isEmpty) {
                      return Center(child: Text('还没有评论，欢迎补充。', style: text.bodySmall));
                    }
                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final body = item['body'] as String? ?? '';
                        final at = item['createdAt'] as String? ?? '';
                        return PaperCard(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(body, style: text.bodyMedium),
                              if (at.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(at, style: text.bodySmall?.copyWith(color: paperInkSoft)),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: '写一条评论…',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _sending ? null : _send,
                    child: _sending
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('发送'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _PointCorrectionsSheet extends StatefulWidget {
  const _PointCorrectionsSheet({
    required this.repository,
    required this.band,
    required this.concept,
    required this.degree,
    required this.position,
    required this.pointText,
  });

  final StudyRepository repository;
  final AgeBand band;
  final Concept concept;
  final StudyDegree degree;
  final int position;
  final String pointText;

  @override
  State<_PointCorrectionsSheet> createState() => _PointCorrectionsSheetState();
}

class _PointCorrectionsSheetState extends State<_PointCorrectionsSheet> {
  late Future<List<Map<String, dynamic>>> _future;
  final _bodyController = TextEditingController();
  final _suggestionController = TextEditingController();
  final _pointsController = TextEditingController(text: '5');
  var _sending = false;
  var _reviewingId = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() {
    return widget.repository.fetchPointCorrections(
      conceptId: widget.concept.id,
      ageBandId: widget.band.id,
      degreeId: widget.degree.id,
      position: widget.position,
    );
  }

  Future<void> _reload() async {
    setState(() { _future = _load(); });
  }

  @override
  void dispose() {
    _bodyController.dispose();
    _suggestionController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final body = _bodyController.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.repository.createPointCorrection(
        conceptId: widget.concept.id,
        ageBandId: widget.band.id,
        degreeId: widget.degree.id,
        position: widget.position,
        body: body,
        suggestedText: _suggestionController.text.trim().isEmpty ? null : _suggestionController.text.trim(),
      );
      _bodyController.clear();
      _suggestionController.clear();
      await _reload();
      if (mounted) {
        showSuccessToast(context, '纠错已提交');
      }
    } catch (e) {
      if (mounted) {
        await showFailureDialog(context, title: '纠错提交失败', reason: '$e');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _review(String correctionId, bool approve) async {
    if (_reviewingId.isNotEmpty) return;
    if (!AuthSession.isAdmin) {
      showInfoToast(context, '普通用户只读，请先用管理员账号在「我的」页登录。');
      return;
    }
    setState(() => _reviewingId = correctionId);
    try {
      final points = int.tryParse(_pointsController.text.trim()) ?? 0;
      await widget.repository.reviewPointCorrection(
        correctionId: correctionId,
        approve: approve,
        points: approve ? points : 0,
      );
      await _reload();
      if (mounted) {
        showSuccessToast(context, approve ? '已审核通过并发放积分' : '已驳回纠错');
      }
    } catch (e) {
      if (mounted) {
        await showFailureDialog(context, title: '审核失败', reason: '$e');
      }
    } finally {
      if (mounted) setState(() => _reviewingId = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.78,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('纠错与审核', style: text.titleMedium),
              const SizedBox(height: 4),
              Text(widget.pointText, style: text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Row(children: [
                const Text('通过奖励积分：'),
                SizedBox(width: 80, child: TextField(controller: _pointsController, keyboardType: TextInputType.number, decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()))),
              ]),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: paperOchre));
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('加载失败：${snapshot.error}', style: text.bodySmall));
                    }
                    final items = snapshot.data ?? const [];
                    if (items.isEmpty) {
                      return Center(child: Text('暂无纠错，可在下方提交。', style: text.bodySmall));
                    }
                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final id = item['id'] as String? ?? '';
                        final status = item['status'] as String? ?? 'pending';
                        final body = item['body'] as String? ?? '';
                        final suggested = item['suggestedText'] as String?;
                        final pts = item['pointsAwarded'];
                        final busy = _reviewingId == id;
                        return PaperCard(
                          padding: const EdgeInsets.all(12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text('状态：$status${status == 'approved' && pts != null ? ' · 积分+$pts' : ''}', style: text.labelMedium)),
                            ]),
                            const SizedBox(height: 4),
                            Text(body, style: text.bodyMedium),
                            if (suggested != null && suggested.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('建议：$suggested', style: text.bodySmall),
                            ],
                            if (status == 'pending') ...[
                              const SizedBox(height: 8),
                              Wrap(spacing: 8, children: [
                                FilledButton.tonal(
                                  onPressed: busy ? null : () => _review(id, false),
                                  child: const Text('驳回'),
                                ),
                                FilledButton(
                                  onPressed: busy ? null : () => _review(id, true),
                                  child: busy ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('通过并给分'),
                                ),
                              ]),
                            ],
                          ]),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text('提交新纠错', style: text.labelMedium),
              const SizedBox(height: 6),
              TextField(controller: _bodyController, maxLines: 2, decoration: const InputDecoration(hintText: '问题说明', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 6),
              TextField(controller: _suggestionController, maxLines: 2, decoration: const InputDecoration(hintText: '建议内容（可选）', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _sending ? null : _submit,
                  child: _sending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('提交纠错'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

