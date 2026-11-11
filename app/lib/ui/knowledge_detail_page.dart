import 'package:flutter/material.dart';

import '../archive/local_archive.dart';
import '../knowledge/age_band.dart';
import '../knowledge/concept.dart';
import '../knowledge/domain.dart';
import '../knowledge/knowledge_graph.dart';
import '../learning/learner_state.dart';
import '../plan/study_plan.dart';
import 'concept_page.dart';
import 'plan_editor_page.dart';
import 'theme.dart';
import 'widgets/glyph_badge.dart';

/// 知识详情页（占位版）：详情内容还在打磨，先把两个去处留住。
///
/// 这一页之后会补上「这一步讲什么、怎么练、前置是什么」；
/// 现在先给学习者一条直路：直接学，或者排进计划。
class KnowledgeDetailPage extends StatefulWidget {
  const KnowledgeDetailPage({
    super.key,
    required this.archive,
    required this.graph,
    required this.band,
    required this.domain,
    required this.concept,
    required this.learner,
  });

  final LocalArchive archive;
  final KnowledgeGraph graph;
  final AgeBand band;
  final LearningDomain domain;
  final Concept concept;

  /// 进入时的学习者状态；学完一步后会重新读取档案。
  final LearnerState learner;

  @override
  State<KnowledgeDetailPage> createState() => _KnowledgeDetailPageState();
}

class _KnowledgeDetailPageState extends State<KnowledgeDetailPage> {
  late LearnerState _learner = widget.learner;

  /// 重新读档案，让学习程度跟着更新。
  Future<void> _reload() async {
    final archive = await widget.archive.load();
    if (!mounted) {
      return;
    }
    setState(() => _learner = LearnerState.fromRecords(archive.records));
  }

  /// 直接学这一步；回来刷新档位。
  Future<void> _start() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConceptPage(
          archive: widget.archive,
          band: widget.band,
          domain: widget.domain,
          concept: widget.concept,
        ),
      ),
    );
    await _reload();
  }

  /// 加入学习计划：预选这个领域，保存后带着计划回到上一页。
  Future<void> _addToPlan() async {
    final plan = await Navigator.of(context).push<StudyPlan>(
      MaterialPageRoute<StudyPlan>(
        builder: (_) => PlanEditorPage(
          graph: widget.graph,
          band: widget.band,
          initialDomainId: widget.domain.id,
          initialDepth: PlanDepth.brief,
        ),
      ),
    );
    if (plan == null || !mounted) {
      return;
    }
    Navigator.of(context).pop(plan);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final variant = widget.concept.variantFor(widget.band);
    final tier = _learner.tierOf(widget.concept.id);
    final practiceCount = _learner.practiceCount(widget.concept.id);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.band.showsSubjectNames ? widget.domain.name : '这一步',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
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
                      if (variant.note != null) ...[
                        const SizedBox(height: 6),
                        Text(variant.note!, style: text.bodySmall),
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
                MasteryPill(label: '第 ${widget.concept.depth + 1} 层'),
                MasteryPill(
                  label: tier?.label ?? '未开始',
                  color: tier == null ? paperStone : paperOchre,
                ),
                if (practiceCount > 0)
                  MasteryPill(
                    label: '练过 $practiceCount 次',
                    color: paperInkSoft,
                  ),
              ],
            ),
            const SizedBox(height: 20),
            _placeholderCard(context),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('start_concept'),
              onPressed: _start,
              child: const Text('开始学这一步'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              key: const Key('add_to_plan'),
              onPressed: _addToPlan,
              child: const Text('加入学习计划'),
            ),
            const SizedBox(height: 8),
            Text(
              '加入后会在「规划」里按时间提醒你。',
              textAlign: TextAlign.center,
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  /// 占位说明：告诉学习者这页之后会有什么，现在能先做什么。
  Widget _placeholderCard(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PaperCard(
      color: paperOchre.withValues(alpha: 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_stories_outlined,
                size: 20,
                color: paperInkSoft,
              ),
              const SizedBox(width: 8),
              Text('详情还在写', style: text.titleMedium),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '这里之后会放：这一步讲什么、怎么练、需要先会什么，'
            '以及同一个概念在别的年龄档怎么说。',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '现在可以直接开始，或者先把它排进计划。',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}
