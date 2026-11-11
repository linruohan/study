import 'package:flutter/material.dart';

import '../archive/local_archive.dart';
import '../knowledge/age_band.dart';
import '../knowledge/concept.dart';
import '../knowledge/domain.dart';
import '../knowledge/knowledge_graph.dart';
import '../knowledge/study_degree.dart';
import '../learning/learner_state.dart';
import '../plan/study_plan.dart';
import 'theme.dart';
import 'widgets/glyph_badge.dart';

/// 知识详情页：知识简介，加入门、熟悉、精通三个程度的知识点。
///
/// 每个程度 tab 里列出该程度的知识点；底部按当前看的程度
/// 把这个知识加进「我的计划」。已经在计划里的程度不再重复添加。
class KnowledgeDetailPage extends StatefulWidget {
  const KnowledgeDetailPage({
    super.key,
    required this.archive,
    required this.graph,
    required this.band,
    required this.domain,
    required this.concept,
    required this.learner,
    required this.plans,
    required this.onAddPlan,
  });

  final LocalArchive archive;
  final KnowledgeGraph graph;
  final AgeBand band;
  final LearningDomain domain;
  final Concept concept;

  /// 进入时的学习者状态；学完一步后会重新读取档案。
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
  /// 进入时的掌握状态；加入计划不改变它，所以可以直接 final。
  late final LearnerState _learner = widget.learner;

  late final TabController _tabs = TabController(
    length: StudyDegree.values.length,
    vsync: this,
  )..addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

  /// 当前 tab 对应的学习程度。
  StudyDegree get _degree => StudyDegree.values[_tabs.index];

  /// 这个知识已经加进计划的程度。
  Set<StudyDegree> get _plannedDegrees {
    return {
      for (final plan in widget.plans)
        if (plan.conceptId == widget.concept.id && plan.degree != null)
          plan.degree!,
    };
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// 按当前程度把这个知识加进计划；已加过的程度给一句确认。
  Future<void> _addToPlan() async {
    final degree = _degree;
    if (_plannedDegrees.contains(degree)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('这个知识已在计划里（${degree.label}）')),
      );
      return;
    }
    final now = DateTime.now();
    widget.onAddPlan(
      StudyPlan(
        id: 'plan_${now.microsecondsSinceEpoch}',
        domainId: widget.domain.id,
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已加入计划 · ${degree.label}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final variant = widget.concept.variantFor(widget.band);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.band.showsSubjectNames ? widget.domain.name : '这一步',
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: paperOchre,
          unselectedLabelColor: paperInkSoft,
          indicatorColor: paperOchre,
          tabs: [
            for (final degree in StudyDegree.values) Tab(text: degree.label),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabs,
          children: [
            for (final degree in StudyDegree.values)
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

  /// 一个程度 tab：顶部掌握状态，中间知识点列表。
  Widget _degreeTab(
    BuildContext context,
    StudyDegree degree,
    ConceptVariant variant,
  ) {
    final text = Theme.of(context).textTheme;
    final tier = _learner.tierOf(widget.concept.id);
    final practiceCount = _learner.practiceCount(widget.concept.id);
    final planned = _plannedDegrees.contains(degree);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlyphBadge(
              glyph: variant.glyph ?? widget.domain.glyph,
              color: widget.domain.color,
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
        Text('「${degree.label}」要学的知识点', style: text.titleMedium),
        const SizedBox(height: 10),
        for (final point in variant.pointsFor(degree)) ...[
          PaperCard(
            key: Key('point_${degree.name}_${variant.pointsFor(degree).indexOf(point)}'),            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 20, color: paperOchre),
                const SizedBox(width: 10),
                Expanded(child: Text(point, style: text.bodyMedium)),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        Text(
          '加入计划后，在「规划」页按领域分组学习这些知识点。',
          textAlign: TextAlign.center,
          style: text.bodySmall,
        ),
      ],
    );
  }
}
