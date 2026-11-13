import 'package:flutter/material.dart';

import '../archive/archive_store.dart';
import '../knowledge/age_band.dart';
import '../knowledge/concept.dart';
import '../knowledge/domain.dart';
import '../knowledge/knowledge_catalog.dart';
import '../knowledge/knowledge_graph.dart';
import '../knowledge/study_degree.dart';
import '../learning/learner_state.dart';
import '../plan/study_plan.dart';
import 'degree_learning_page.dart';
import 'feedback.dart';
import 'theme.dart';
import 'widgets/empty_state.dart';
import 'widgets/glyph_badge.dart';
import 'widgets/page_header.dart';

/// 双栏生效的最小宽度；低于它左右面板改为上下布局。
const _twoPaneMinWidth = 720.0;

/// 规划页：左右结构。左侧按领域分组列出计划里的知识，
/// 右侧显示选中领域的「学习中」和「未开始」两段。
///
/// 只收知识级计划（从知识详情页按程度加入的）；
/// 点一条知识进入该程度的知识点学习页。
/// 窗口较窄时左侧领域栏收成一行横滑，右侧列表占满全宽。
class PlanView extends StatefulWidget {
  const PlanView({
    super.key,
    required this.archive,
    required this.graph,
    required this.band,
    required this.learner,
    required this.plans,
    required this.onDeleted,
    required this.onAddConceptPlan,
    required this.onReload,
  });

  final ArchiveStore archive;
  final KnowledgeGraph graph;
  final AgeBand band;
  final LearnerState learner;

  /// 本机全部计划；本页只看其中带 conceptId 的知识级计划。
  final List<StudyPlan> plans;

  /// 删除一条计划后回调首页。
  final void Function(StudyPlan plan) onDeleted;

  /// 把「这个领域还有」的一条知识按入门程度排进计划，由首页写簿。
  final void Function(Concept concept, LearningDomain domain) onAddConceptPlan;

  /// 回到本页时重新读取档案，刷新学习中/未开始的分组。
  final VoidCallback onReload;

  @override
  State<PlanView> createState() => _PlanViewState();
}

class _PlanViewState extends State<PlanView> {
  /// 左侧选中的领域 id；空时默认选第一个有计划的领域。
  String? _selectedDomainId;

  /// 知识级计划，按领域分组。
  Map<LearningDomain, List<StudyPlan>> get _grouped {
    final grouped = <LearningDomain, List<StudyPlan>>{};
    for (final plan in widget.plans) {
      final conceptId = plan.conceptId;
      if (conceptId == null) {
        continue;
      }
      final domain = widget.graph.domainById(plan.domainId);
      if (domain == null) {
        continue;
      }
      grouped.putIfAbsent(domain, () => []).add(plan);
    }
    return grouped;
  }

  /// 左侧选中的领域。
  LearningDomain? get _selected {
    final grouped = _grouped;
    if (grouped.isEmpty) {
      return null;
    }
    for (final domain in grouped.keys) {
      if (domain.id == _selectedDomainId) {
        return domain;
      }
    }
    return grouped.keys.first;
  }

  /// 某领域下还没加进计划的同领域知识，用来补「未开始」段。
  ///
  /// 规则：该领域本档全部知识中，不在本领域计划里的都列出来，
  /// 已掌握（熟练及以上）的不列，避免清单越学越长。
  List<Concept> _unplannedOf(LearningDomain domain, List<StudyPlan> planned) {
    final plannedIds = {
      for (final plan in planned)
        if (plan.conceptId != null) plan.conceptId!,
    };
    return domain
        .conceptsFor(widget.band)
        .where((concept) =>
            !plannedIds.contains(concept.id) &&
            !(widget.learner.tierOf(concept.id)?.unlocksNext ?? false))
        .toList();
  }

  /// 进入知识点学习页；回来后让首页重读档案。
  Future<void> _openPlan(StudyPlan plan) async {
    final concept = widget.graph.conceptById(plan.conceptId!);
    final domain = widget.graph.domainById(plan.domainId);
    if (concept == null || domain == null || !concept.availableIn(widget.band)) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DegreeLearningPage(
          archive: widget.archive,
          band: widget.band,
          domain: domain,
          concept: concept,
          degree: plan.degree ?? KnowledgeCatalog.instance.degrees.first,
        ),
      ),
    );
    if (mounted) {
      widget.onReload();
    }
  }

  /// 把一条还没排进计划的知识加进计划（默认入门程度）。
  void _addUnplanned(Concept concept, LearningDomain domain) {
    widget.onAddConceptPlan(
      concept,
      domain,
    );
    showSuccessToast(
      context,
      '已加入计划 · ${KnowledgeCatalog.instance.degrees.first.label}',
    );
  }

  /// 删除一条知识计划，删除前确认一次。
  Future<void> _delete(StudyPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('把这条知识移出计划？'),
        content: Text(
          '${widget.graph.domainById(plan.domainId)?.name ?? ''} · '
          '${plan.degree?.label ?? ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('留着'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('移出'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      widget.onDeleted(plan);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: PageHeader(
              title: '我的计划',
              subtitle: '按领域分组。点一条知识，按选好的程度逐条学知识点。',
            ),
          ),
          Expanded(
            child: grouped.isEmpty
                ? Center(
                    child: EmptyState(
                      icon: Icons.event_note_outlined,
                      title: '计划里还没有知识',
                      message: '到「知识库」选一条知识，挑一个学习程度加进来。',
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final wide =
                          constraints.maxWidth >= _twoPaneMinWidth;
                      if (wide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: 200,
                              child: _domainPanel(context, grouped),
                            ),
                            const SizedBox(width: 16),
                            Expanded(child: _detailPanel(context, grouped)),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _domainStrip(context, grouped),
                          const SizedBox(height: 12),
                          Expanded(child: _detailPanel(context, grouped)),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// 左侧领域分组：符号、名称、条数。
  Widget _domainPanel(
    BuildContext context,
    Map<LearningDomain, List<StudyPlan>> grouped,
  ) {
    final selected = _selected;
    return Container(
      decoration: BoxDecoration(
        color: paperSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: paperLine),
      ),
      child: ListView.builder(
        key: const PageStorageKey('plan_domains'),
        padding: const EdgeInsets.symmetric(vertical: 10),
        itemCount: grouped.length,
        itemBuilder: (context, index) {
          final entry = grouped.entries.elementAt(index);
          return _domainRow(context, entry.key, entry.value, selected);
        },
      ),
    );
  }

  /// 窄窗口的领域条：一行横滑的小卡，选中的带淡赭底。
  Widget _domainStrip(
    BuildContext context,
    Map<LearningDomain, List<StudyPlan>> grouped,
  ) {
    final selected = _selected;
    return SizedBox(
      height: 56,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: grouped.length,
        itemBuilder: (context, index) {
          final entry = grouped.entries.elementAt(index);
          final domain = entry.key;
          final isSelected = domain == selected;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: PaperCard(
              key: Key('plan_domain_${domain.id}'),
              onTap: () => setState(() => _selectedDomainId = domain.id),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              color: isSelected
                  ? paperOchre.withValues(alpha: 0.08)
                  : paperSurface,
              child: Row(
                children: [
                  GlyphBadge(
                    glyph: domain.glyph,
                    color: domain.color,
                    size: 26,
                    fontSize: 13,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    domain.displayNameFor(widget.band),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${entry.value.length}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 一行领域分组：符号、名称、条数；选中时淡赭底。
  Widget _domainRow(
    BuildContext context,
    LearningDomain domain,
    List<StudyPlan> plans,
    LearningDomain? selected,
  ) {
    return InkWell(
      key: Key('plan_domain_row_${domain.id}'),
      onTap: () => setState(() => _selectedDomainId = domain.id),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: domain == selected
              ? paperOchre.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            GlyphBadge(
              glyph: domain.glyph,
              color: domain.color,
              size: 30,
              fontSize: 14,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                domain.displayNameFor(widget.band),
                style: Theme.of(context).textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${plans.length}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  /// 右侧两段：学习中（有练习记录）和未开始（还没加进计划的知识）。
  Widget _detailPanel(
    BuildContext context,
    Map<LearningDomain, List<StudyPlan>> grouped,
  ) {
    final domain = _selected;
    if (domain == null) {
      return const SizedBox.shrink();
    }
    final plans = grouped[domain] ?? const [];
    final learning = <(StudyPlan, Concept, StudyDegree)>[];
    for (final plan in plans) {
      final concept = widget.graph.conceptById(plan.conceptId!);
      if (concept == null) {
        continue;
      }
      if (widget.learner.tierOf(concept.id) != null) {
        learning.add((plan, concept, plan.degree ?? KnowledgeCatalog.instance.degrees.first));
      }
    }
    final notStarted = <(StudyPlan, Concept, StudyDegree)>[];
    for (final plan in plans) {
      final concept = widget.graph.conceptById(plan.conceptId!);
      if (concept == null) {
        continue;
      }
      if (widget.learner.tierOf(concept.id) == null) {
        notStarted.add((plan, concept, plan.degree ?? KnowledgeCatalog.instance.degrees.first));
      }
    }
    final unplanned = _unplannedOf(domain, plans);
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: paperSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: paperLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
            child: Text(
              domain.displayNameFor(widget.band),
              style: text.headlineSmall,
            ),
          ),
          const Divider(height: 1, color: paperLine),
          Expanded(
            child: learning.isEmpty && notStarted.isEmpty && unplanned.isEmpty
                ? Center(
                    child: EmptyState(
                      icon: Icons.school_outlined,
                      title: '这个领域还没有知识',
                      message: '左侧选中一个领域，右边就会列出它的知识。',
                    ),
                  )
                : ListView.builder(
                    key: PageStorageKey('plan_detail_${domain.id}'),
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
                    itemCount: learning.length +
                        (learning.isEmpty ? 0 : 1) +
                        notStarted.length +
                        (notStarted.isEmpty ? 0 : 1) +
                        unplanned.length +
                        (unplanned.isEmpty ? 0 : 1),
                    itemBuilder: (context, index) {
                      final entry = _detailRow(
                        index,
                        learning,
                        notStarted,
                        unplanned,
                      );
                      if (entry == null) {
                        return const SizedBox.shrink();
                      }
                      return switch (entry) {
                        _TitleRow(:final title, :final note) => Padding(
                            padding: const EdgeInsets.only(top: 2, bottom: 10),
                            child: _groupTitle(context, title, note),
                          ),
                        _PlanRow(:final entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _planCard(context, entry, learning: true),
                          ),
                        _NotStartedRow(:final entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _planCard(context, entry, learning: false),
                          ),
                        _UnplannedRow(:final concept) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _unplannedCard(context, concept, domain),
                          ),
                      };
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// 把平铺下标映射到一行：标题行、计划卡或「这个领域还有」的卡。
  _DetailRow? _detailRow(
    int index,
    List<(StudyPlan, Concept, StudyDegree)> learning,
    List<(StudyPlan, Concept, StudyDegree)> notStarted,
    List<Concept> unplanned,
  ) {
    if (learning.isNotEmpty) {
      if (index == 0) {
        return _TitleRow('学习中', '${learning.length} 条');
      }
      index -= 1;
      if (index < learning.length) {
        return _PlanRow(learning[index]);
      }
      index -= learning.length;
    }
    if (notStarted.isNotEmpty) {
      if (index == 0) {
        return _TitleRow('未开始', '${notStarted.length} 条');
      }
      index -= 1;
      if (index < notStarted.length) {
        return _NotStartedRow(notStarted[index]);
      }
      index -= notStarted.length;
    }
    if (unplanned.isNotEmpty) {
      if (index == 0) {
        return _TitleRow('这个领域还有', '${unplanned.length} 条没排进来');
      }
      index -= 1;
      if (index < unplanned.length) {
        return _UnplannedRow(unplanned[index]);
      }
    }
    return null;
  }

  /// 段标题：名称加数量合并成一行，避免和卡片上的状态标签重名。
  Widget _groupTitle(BuildContext context, String title, String note) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Text('$title · $note', style: text.titleMedium),
      ],
    );
  }

  /// 一条计划里的知识：程度标签、掌握状态，点开进入学习页。
  Widget _planCard(
    BuildContext context,
    (StudyPlan, Concept, StudyDegree) entry, {
    required bool learning,
  }) {
    final (plan, concept, degree) = entry;
    final text = Theme.of(context).textTheme;
    final variant = concept.variantFor(widget.band);
    final tier = widget.learner.tierOf(concept.id);
    return PaperCard(
      key: Key('plan_concept_${concept.id}'),
      onTap: () => _openPlan(plan),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          GlyphBadge(
            glyph: variant.glyph ?? widget.graph.domainById(plan.domainId)?.glyph ?? '·',
            color: widget.graph.domainById(plan.domainId)?.color ?? paperInkSoft,
            size: 46,
            rounded: true,
            fontSize: 22,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(variant.topic, style: text.titleMedium),
                const SizedBox(height: 4),
                Text('按「${degree.label}」程度学习', style: text.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          MasteryPill(
            label: tier?.label ?? '未开始',
            color: tier == null ? paperInkSoft : paperOchre,
          ),
          _deleteButton(context, plan),
        ],
      ),
    );
  }

  /// 「这个领域还有」的卡片：一键按入门程度排进计划。
  Widget _unplannedCard(
    BuildContext context,
    Concept concept,
    LearningDomain domain,
  ) {
    final text = Theme.of(context).textTheme;
    final variant = concept.variantFor(widget.band);
    return PaperCard(
      key: Key('plan_unplanned_${concept.id}'),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(
        children: [
          GlyphBadge(
            glyph: variant.glyph ?? domain.glyph,
            color: domain.color,
            size: 40,
            rounded: true,
            fontSize: 18,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(variant.topic, style: text.titleMedium)),
          TextButton.icon(
            key: Key('plan_add_${concept.id}'),
            onPressed: () => _addUnplanned(concept, domain),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('排进来'),
          ),
        ],
      ),
    );
  }

  /// 长按或右侧菜单删除；放一个不显眼的入口，避免误触。
  Widget _deleteButton(BuildContext context, StudyPlan plan) {
    return IconButton(
      key: Key('delete_plan_${plan.id}'),
      tooltip: '移出计划',
      onPressed: () => _delete(plan),
      icon: const Icon(Icons.more_vert, size: 20, color: paperInkSoft),
    );
  }
}

/// 详情列表的一行：标题、学习中的计划、未开始的计划或没排进来的知识。
sealed class _DetailRow {
  const _DetailRow();
}

/// 详情列表里的一行标题。
class _TitleRow extends _DetailRow {
  const _TitleRow(this.title, this.note);

  final String title;
  final String note;
}

/// 详情列表里的一条学习中的计划。
class _PlanRow extends _DetailRow {
  const _PlanRow(this.entry);

  final (StudyPlan, Concept, StudyDegree) entry;
}

/// 详情列表里的一条未开始的计划。
class _NotStartedRow extends _DetailRow {
  const _NotStartedRow(this.entry);

  final (StudyPlan, Concept, StudyDegree) entry;
}

/// 详情列表里的一条还没排进计划的知识。
class _UnplannedRow extends _DetailRow {
  const _UnplannedRow(this.concept);

  final Concept concept;
}
