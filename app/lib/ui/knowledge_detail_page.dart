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

/// 知识详情页：说清这一步讲什么、怎么练、前置是什么，并给出两个去处。
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
  var _showAnswer = false;

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

  /// 加入学习计划：预选这个领域，保存后带着计划回到首页。
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
            Text(variant.topic, style: text.headlineMedium),
            if (variant.note != null) ...[
              const SizedBox(height: 10),
              Text(variant.note!, style: text.bodySmall),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                MasteryPill(label: '第 ${widget.concept.depth + 1} 层'),
                MasteryPill(
                  label: tier?.label ?? '未开始',
                  color: tier == null ? paperStone : paperOchre,
                ),
                if (_learner.practiceCount(widget.concept.id) > 0)
                  MasteryPill(
                    label: '练过 ${_learner.practiceCount(widget.concept.id)} 次',
                    color: paperInkSoft,
                  ),
              ],
            ),
            const SizedBox(height: 20),
            _card(
              context,
              '这一步做什么',
              Text(variant.doing, style: text.bodyMedium),
            ),
            const SizedBox(height: 12),
            _checkCard(context, variant),
            const SizedBox(height: 12),
            _domainProgressCard(context),
            const SizedBox(height: 12),
            _prerequisiteCard(context),
            const SizedBox(height: 12),
            _otherBandsCard(context, variant),
            const SizedBox(height: 22),
            FilledButton(
              key: const Key('start_concept'),
              onPressed: _start,
              style: FilledButton.styleFrom(
                backgroundColor: widget.domain.color,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
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
              '加入后会在「学习」里按领域分组，到时间会提醒你。',
              textAlign: TextAlign.center,
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  /// 一张带标题的纸卡，减少重复排版。
  Widget _card(BuildContext context, String title, Widget child) {
    final text = Theme.of(context).textTheme;
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.titleMedium),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  /// 形成性提问：先想一想，再看一句参考回应。
  Widget _checkCard(BuildContext context, ConceptVariant variant) {
    final text = Theme.of(context).textTheme;
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('想一想', style: text.titleMedium),
          const SizedBox(height: 6),
          Text(variant.check, style: text.bodyMedium),
          const SizedBox(height: 8),
          if (_showAnswer)
            Text(
              variant.answer,
              style: text.bodySmall?.copyWith(color: paperOchre),
            )
          else
            TextButton(
              onPressed: () => setState(() => _showAnswer = true),
              child: const Text('看一句回应'),
            ),
        ],
      ),
    );
  }

  /// 这个领域在本档的整体进度：这一格在整条路上走到哪了。
  Widget _domainProgressCard(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final concepts = widget.domain.conceptsFor(widget.band);
    final ready = _learner.readyIds;
    final readyCount =
        concepts.where((concept) => ready.contains(concept.id)).length;
    final total = concepts.length;
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                widget.band.showsSubjectNames
                    ? '${widget.domain.name}整体进度'
                    : '这个领域整体进度',
                style: text.titleMedium,
              ),
              const Spacer(),
              Text('熟练 $readyCount/$total 步', style: text.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          // 熟练步数占比，看到这一格在整条路上的位置。
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : readyCount / total,
              minHeight: 4,
              backgroundColor: paperLine,
              valueColor: AlwaysStoppedAnimation<Color>(widget.domain.color),
            ),
          ),
        ],
      ),
    );
  }

  /// 前置知识：列出还没练到熟练的那几项。
  Widget _prerequisiteCard(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final prerequisites = widget.concept.prerequisites;
    final ready = _learner.readyIds;
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('前置', style: text.titleMedium),
          const SizedBox(height: 6),
          if (prerequisites.isEmpty)
            Text('没有前置，可以直接开始。', style: text.bodySmall)
          else
            for (final id in prerequisites) ...[
              _prerequisiteRow(context, id, ready),
              const SizedBox(height: 6),
            ],
        ],
      ),
    );
  }

  /// 一条前置：名称加熟练状态；不在本档出现的只作说明。
  Widget _prerequisiteRow(BuildContext context, String id, Set<String> ready) {
    final text = Theme.of(context).textTheme;
    final concept = widget.graph.conceptById(id);
    final inBand = concept != null && concept.availableIn(widget.band);
    final topic = inBand
        ? concept.variantFor(widget.band).topic
        : (concept?.variants.values.first.topic ?? id);
    final done = ready.contains(id);
    return Row(
      children: [
        Icon(
          done ? Icons.check_circle_outline : Icons.radio_button_unchecked,
          size: 18,
          color: done ? paperOchre : paperInkSoft,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(topic, style: text.bodySmall)),
        if (!inBand) Text('更早的一档', style: text.bodySmall),
      ],
    );
  }

  /// 跨年龄的呈现：同一概念在不同年龄换说法。
  Widget _otherBandsCard(BuildContext context, ConceptVariant current) {
    final text = Theme.of(context).textTheme;
    final others = widget.concept.variants.entries
        .where((entry) => entry.value != current)
        .toList()
      ..sort((a, b) => a.key.index.compareTo(b.key.index));
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('别的年龄档', style: text.titleMedium),
          const SizedBox(height: 6),
          if (others.isEmpty)
            Text('这一条只有现在这一档。', style: text.bodySmall)
          else
            for (final entry in others)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 64,
                      child: Text(entry.key.shortLabel, style: text.bodySmall),
                    ),
                    Expanded(
                      child: Text(
                        entry.value.topic,
                        style: text.bodySmall?.copyWith(color: paperInk),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
