import 'package:flutter/material.dart';

import '../knowledge/age_band.dart';
import '../knowledge/concept.dart';
import '../knowledge/domain.dart';
import '../knowledge/knowledge_graph.dart';
import '../learning/learner_state.dart';
import '../plan/plan_text.dart';
import '../plan/study_plan.dart';
import 'theme.dart';
import 'today_card.dart';

/// 学习入口：先给今日一步，再按领域列出已经排进计划的知识。
class LearnView extends StatelessWidget {
  const LearnView({
    super.key,
    required this.graph,
    required this.band,
    required this.learner,
    required this.focusDomainId,
    required this.recordCount,
    required this.plans,
    required this.showDonePlans,
    required this.onToggleDonePlans,
    required this.onOpenToday,
    required this.onAddPlan,
    required this.onOpenPlan,
    required this.onToggleDone,
    required this.onDeletePlan,
    required this.onChangeBand,
  });

  final KnowledgeGraph graph;
  final AgeBand band;
  final LearnerState learner;
  final String? focusDomainId;
  final int recordCount;
  final List<StudyPlan> plans;

  /// 已完成计划是否展开；默认收起，不让旧计划占满屏幕。
  final bool showDonePlans;

  final VoidCallback onToggleDonePlans;

  /// 点今日一步。
  final void Function(Concept concept, LearningDomain domain) onOpenToday;

  final VoidCallback onAddPlan;
  final void Function(StudyPlan plan) onOpenPlan;
  final void Function(StudyPlan plan) onToggleDone;
  final void Function(StudyPlan plan) onDeletePlan;

  /// 本档全部走到熟练后，换个年龄档继续。
  final VoidCallback onChangeBand;

  /// 按领域分组，只保留有计划的领域；未完成在前、已完成在后。
  ///
  /// 已完成单独拿出来，界面上默认折起来，需要时再展开。
  List<
      ({
        LearningDomain domain,
        List<StudyPlan> active,
        List<StudyPlan> done,
      })> _sections() {
    final sections = <({
      LearningDomain domain,
      List<StudyPlan> active,
      List<StudyPlan> done,
    })>[];
    for (final domain in graph.domainsFor(band)) {
      final domainPlans =
          plans.where((plan) => plan.domainId == domain.id).toList()
            ..sort((a, b) => a.startAt.compareTo(b.startAt));
      final active = domainPlans.where((plan) => !plan.done).toList();
      final done = domainPlans.where((plan) => plan.done).toList();
      if (domainPlans.isNotEmpty) {
        sections.add((domain: domain, active: active, done: done));
      }
    }
    return sections;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final concept = graph.nextStep(
      band,
      learner.readyIds,
      focusDomainId: focusDomainId,
    );
    final domain = concept == null ? null : graph.domainById(concept.domainId);
    final sections = _sections();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Row(
          children: [
            Text('学习', style: text.titleMedium),
            const Spacer(),
            TextButton.icon(
              key: const Key('add_plan'),
              onPressed: onAddPlan,
              icon: const Icon(Icons.add, size: 18, color: paperOchre),
              label: const Text('新建计划'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '下面是排进计划的知识，点一条进入正式学习；没排也可以先做今日一步。',
          style: text.bodySmall,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text('已加入计划', style: text.titleMedium),
            const Spacer(),
            Text('${plans.length} 条', style: text.bodySmall),
          ],
        ),
        const SizedBox(height: 6),
        Text('每条都带学习程度。学完会进入小测，再记一次档案。', style: text.bodySmall),
        const SizedBox(height: 14),
        if (sections.isEmpty)
          _emptyPlans(context)
        else
          for (final section in sections) ...[
            _sectionHeader(
              context,
              section.domain,
              section.active.length,
              section.done.length,
            ),
            const SizedBox(height: 10),
            for (final plan in section.active) ...[
              _planCard(context, plan, section.domain),
              const SizedBox(height: 10),
            ],
            if (section.done.isNotEmpty) ...[
              _doneToggle(context, section.domain, section.done.length),
              if (showDonePlans) ...[
                const SizedBox(height: 6),
                for (final plan in section.done) ...[
                  _planCard(context, plan, section.domain),
                  const SizedBox(height: 10),
                ],
              ],
            ],
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 22),
        Text('今日一步', style: text.titleMedium),
        const SizedBox(height: 10),
        if (concept != null && domain != null)
          TodayCard(
            band: band,
            concept: concept,
            domain: domain,
            tier: learner.tierOf(concept.id),
            onTap: () => onOpenToday(concept, domain),
          )
        else
          PaperCard(
            child: Column(
              children: [
                Text(
                  '这一档能走的都到熟练了。可以换一档，或者到「知识库」复习。',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium,
                ),
                const SizedBox(height: 12),
                TextButton(
                  key: const Key('change_band_from_today'),
                  onPressed: onChangeBand,
                  child: const Text('换一档看看'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        Text(
          '本机记录 $recordCount 条',
          textAlign: TextAlign.center,
          style: text.bodySmall,
        ),
      ],
    );
  }

  /// 领域分组标题：符号、名称和本领域完成进度。
  Widget _sectionHeader(
    BuildContext context,
    LearningDomain domain,
    int activeCount,
    int doneCount,
  ) {
    final text = Theme.of(context).textTheme;
    final total = activeCount + doneCount;
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: domain.color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              domain.glyph,
              style: TextStyle(fontSize: 14, color: domain.color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(band.showsSubjectNames ? domain.name : '要去的地方', style: text.titleMedium),
        const Spacer(),
        Text('已完成 $doneCount/$total', style: text.bodySmall),
      ],
    );
  }

  /// 已完成计划的折叠行：默认收起，点一下才展开。
  Widget _doneToggle(
    BuildContext context,
    LearningDomain domain,
    int doneCount,
  ) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: Key('done_toggle_${domain.id}'),
        onPressed: onToggleDonePlans,
        icon: Icon(
          showDonePlans ? Icons.expand_less : Icons.expand_more,
          size: 18,
          color: paperInkSoft,
        ),
        label: Text(
          showDonePlans ? '收起已完成 $doneCount 条' : '已完成 $doneCount 条 · 展开',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        style: TextButton.styleFrom(foregroundColor: paperInkSoft),
      ),
    );
  }

  /// 这条计划在本领域里的进度：能学的下一格、是否被前置挡住、已熟练几步。
  ({Concept? next, bool blocked, int ready, int total}) _planProgress(
    LearningDomain domain,
    StudyPlan plan,
  ) {
    final ready = learner.readyIds;
    final limit = plan.depth.maxDepth;
    final scope = domain
        .conceptsFor(band)
        .where((concept) => limit == null || concept.depth <= limit)
        .toList();
    final readyCount = scope.where((concept) => ready.contains(concept.id)).length;
    final remaining =
        scope.where((concept) => !ready.contains(concept.id)).toList();
    final open = remaining
        .where((concept) => graph.unlocked(concept, ready, band))
        .toList()
      ..sort((a, b) {
        final byDepth = a.depth.compareTo(b.depth);
        return byDepth != 0 ? byDepth : a.id.compareTo(b.id);
      });
    return (
      next: open.isEmpty ? null : open.first,
      blocked: open.isEmpty && remaining.isNotEmpty,
      ready: readyCount,
      total: scope.length,
    );
  }

  /// 一条计划：学习程度、时间、状态；点开进入正式学习。
  Widget _planCard(
    BuildContext context,
    StudyPlan plan,
    LearningDomain domain,
  ) {
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final started = plan.due(now);
    final progress = _planProgress(domain, plan);
    final statusLabel = plan.done ? '已完成' : (started ? '可以开始' : '待开始');
    final statusColor = plan.done
        ? paperInkSoft
        : (started ? paperOchre : paperStone);
    return PaperCard(
      key: Key('plan_${plan.id}'),
      onTap: () => onOpenPlan(plan),
      padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: domain.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                domain.glyph,
                style: TextStyle(fontSize: 20, color: domain.color),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        domain.name,
                        style: text.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    MasteryPill(label: statusLabel, color: statusColor),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${plan.depth.label} · ${planTimeLabel(plan.startAt, now: now)}'
                  ' · 熟练 ${progress.ready}/${progress.total} 步'
                  '${plan.remind && !plan.done ? ' · 到点提醒' : ''}',
                  style: text.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  plan.done
                      ? '这一档已经走完，可以再复习一遍。'
                      : (progress.next != null
                          ? '下一步：${progress.next!.variantFor(band).topic}'
                          : (progress.blocked
                              ? '先把前面挡住的步骤练熟。'
                              : '这一档能走的都到熟练了。')),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: paperInk),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: '更多操作',
            onSelected: (value) {
              if (value == 'done') {
                onToggleDone(plan);
              } else if (value == 'delete') {
                onDeletePlan(plan);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'done',
                child: Text(plan.done ? '取消完成' : '标记完成'),
              ),
              const PopupMenuItem(value: 'delete', child: Text('删除计划')),
            ],
          ),
        ],
      ),
    );
  }

  /// 还没有计划时的提示。
  Widget _emptyPlans(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PaperCard(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      child: Column(
        children: [
          const Icon(Icons.event_note_outlined, size: 34, color: paperInkSoft),
          const SizedBox(height: 12),
          Text('还没有学习计划', style: text.titleMedium),
          const SizedBox(height: 6),
          Text(
            '从「知识库」挑一条加入，或者在这里新建。',
            textAlign: TextAlign.center,
            style: text.bodySmall,
          ),
          const SizedBox(height: 14),
          TextButton(onPressed: onAddPlan, child: const Text('建第一条计划')),
        ],
      ),
    );
  }
}
