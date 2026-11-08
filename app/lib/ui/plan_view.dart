import 'package:flutter/material.dart';

import '../knowledge/age_band.dart';
import '../knowledge/knowledge_graph.dart';
import '../plan/plan_text.dart';
import '../plan/study_plan.dart';
import 'theme.dart';

/// 计划入口：列出本机计划，可以新建、去学习、标记完成或删除。
class PlanView extends StatelessWidget {
  const PlanView({
    super.key,
    required this.graph,
    required this.band,
    required this.plans,
    required this.onAdd,
    required this.onOpen,
    required this.onToggleDone,
    required this.onDelete,
  });

  final KnowledgeGraph graph;
  final AgeBand band;
  final List<StudyPlan> plans;
  final VoidCallback onAdd;
  final void Function(StudyPlan plan) onOpen;
  final void Function(StudyPlan plan) onToggleDone;
  final void Function(StudyPlan plan) onDelete;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Row(
          children: [
            Text('学习计划', style: text.titleMedium),
            const Spacer(),
            TextButton.icon(
              key: const Key('add_plan'),
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18, color: paperOchre),
              label: const Text('新建'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text('自己定什么时候开始。到点会提醒，方向可选简单了解或深入学习。',
            style: text.bodySmall),
        const SizedBox(height: 16),
        if (plans.isEmpty)
          _empty(context)
        else
          for (final plan in plans) ...[
            _planCard(context, plan),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  /// 空状态：告诉用户为什么值得建一条计划。
  Widget _empty(BuildContext context) {
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
            '选一个领域和深度，定好什么时候开始。',
            textAlign: TextAlign.center,
            style: text.bodySmall,
          ),
          const SizedBox(height: 14),
          TextButton(onPressed: onAdd, child: const Text('建第一条计划')),
        ],
      ),
    );
  }

  /// 一条计划：领域、方向、时间、状态；点卡片直接去学。
  Widget _planCard(BuildContext context, StudyPlan plan) {
    final text = Theme.of(context).textTheme;
    final domain = graph.domainById(plan.domainId);
    final now = DateTime.now();
    final started = plan.due(now);
    final statusLabel = plan.done ? '已完成' : (started ? '可以开始' : '待开始');
    final statusColor = plan.done
        ? paperInkSoft
        : (started ? paperOchre : paperStone);
    return PaperCard(
      key: Key('plan_${plan.id}'),
      onTap: domain == null ? null : () => onOpen(plan),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (domain?.color ?? paperInkSoft).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                domain?.glyph ?? '·',
                style: TextStyle(
                  fontSize: 20,
                  color: domain?.color ?? paperInkSoft,
                ),
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
                        domain == null
                            ? '这个领域暂时没有了'
                            : (band.showsSubjectNames ? domain.name : '去学习'),
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
                  '${plan.remind && !plan.done ? ' · 到点提醒' : ''}',
                  style: text.bodySmall,
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
                onDelete(plan);
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
}
