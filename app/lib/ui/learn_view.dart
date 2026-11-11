import 'package:flutter/material.dart';

import '../knowledge/age_band.dart';
import '../knowledge/concept.dart';
import '../knowledge/domain.dart';
import '../knowledge/knowledge_graph.dart';
import '../learning/learner_state.dart';
import '../plan/study_plan.dart';
import 'today_card.dart';
import 'widgets/empty_state.dart';
import 'widgets/page_header.dart';
import 'widgets/plan_card.dart';
import 'widgets/section_header.dart';

/// 学习入口：先做今日一步，再看一眼下一条计划。
///
/// 计划本身放在「规划」页，这里只提示最近的一条，避免两页重复列同一批卡片。
class LearnView extends StatelessWidget {
  const LearnView({
    super.key,
    required this.graph,
    required this.band,
    required this.learner,
    required this.focusDomainId,
    required this.recordCount,
    required this.plans,
    required this.onOpenToday,
    required this.onOpenPlan,
    required this.onGoPlan,
    required this.onAddPlan,
    required this.onChangeBand,
  });

  final KnowledgeGraph graph;
  final AgeBand band;
  final LearnerState learner;
  final String? focusDomainId;
  final int recordCount;
  final List<StudyPlan> plans;

  /// 点今日一步。
  final void Function(Concept concept, LearningDomain domain) onOpenToday;

  /// 点下一条计划，直接进入学习。
  final void Function(StudyPlan plan) onOpenPlan;

  /// 去「规划」页看全部计划。
  final VoidCallback onGoPlan;

  /// 快速新建一条计划。
  final VoidCallback onAddPlan;

  /// 本档全部走到熟练后，换个年龄档继续。
  final VoidCallback onChangeBand;

  /// 还没完成、开始时间最早的一条计划；没有就返回 null。
  StudyPlan? get _nextPlan {
    final active = plans.where((plan) => !plan.done).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    return active.isEmpty ? null : active.first;
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
    final nextPlan = _nextPlan;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        const PageHeader(
          title: '学习',
          subtitle: '一次只做一小步。做完会记进本机档案，不用自己打卡。',
        ),
        const SizedBox(height: 18),
        const SectionHeader(title: '今日一步'),
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
          EmptyState(
            icon: Icons.done_all,
            title: '这一档走到头了',
            message: '这一档能走的都到熟练了。可以换一档，或者到「知识库」复习。',
            actionLabel: '换一档看看',
            actionKey: const Key('change_band_from_today'),
            onAction: onChangeBand,
          ),
        const SizedBox(height: 24),
        SectionHeader(
          title: '下一条计划',
          trailing: TextButton(
            key: const Key('go_plan'),
            onPressed: onGoPlan,
            child: const Text('全部计划'),
          ),
        ),
        const SizedBox(height: 6),
        if (nextPlan == null)
          EmptyState(
            icon: Icons.event_note_outlined,
            title: '还没排计划',
            message: '排一条计划，到点会提醒你开始。',
            actionLabel: '建一条计划',
            onAction: onAddPlan,
          )
        else
          PlanCard(
            key: const Key('next_plan'),
            plan: nextPlan,
            graph: graph,
            band: band,
            now: DateTime.now(),
            onTap: () => onOpenPlan(nextPlan),
          ),
        const SizedBox(height: 22),
        Text(
          '本机记录 $recordCount 条',
          textAlign: TextAlign.center,
          style: text.bodySmall,
        ),
      ],
    );
  }
}
