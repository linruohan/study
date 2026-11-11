import 'package:flutter/material.dart';

import '../knowledge/age_band.dart';
import '../knowledge/knowledge_graph.dart';
import '../plan/study_plan.dart';
import 'theme.dart';
import 'widgets/empty_state.dart';
import 'widgets/page_header.dart';
import 'widgets/plan_card.dart';
import 'widgets/section_header.dart';

/// 规划入口：把「什么时候学什么」集中在一页。
///
/// 计划按「可以开始 / 接下来 / 已完成」分三段，已完成默认收起；
/// 点一条直接进入对应领域的阶梯学习。
class PlanView extends StatefulWidget {
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
  State<PlanView> createState() => _PlanViewState();
}

class _PlanViewState extends State<PlanView> {
  /// 已完成计划是否展开；默认收起，不让旧计划占满屏幕。
  var _showDone = false;

  /// 还没完成的计划，按开始时间从早到晚。
  List<StudyPlan> get _active {
    return widget.plans.where((plan) => !plan.done).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
  }

  /// 已完成的计划，最近开始的排在前面。
  List<StudyPlan> get _done {
    return widget.plans.where((plan) => plan.done).toList()
      ..sort((a, b) => b.startAt.compareTo(a.startAt));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final active = _active;
    final done = _done;
    final ready = active.where((plan) => plan.due(now)).toList();
    final upcoming = active.where((plan) => !plan.due(now)).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        PageHeader(
          title: '规划',
          subtitle: '定好什么时候学什么。到点会提醒，方向可选简单了解或深入学习。',
          trailing: TextButton.icon(
            key: const Key('add_plan'),
            onPressed: widget.onAdd,
            icon: const Icon(Icons.add, size: 18, color: paperOchre),
            label: const Text('新建'),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _statCard(context, '可以开始', ready.length, paperOchre),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _statCard(context, '接下来', upcoming.length, paperStone),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _statCard(context, '已完成', done.length, paperInkSoft),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (widget.plans.isEmpty)
          EmptyState(
            icon: Icons.event_note_outlined,
            title: '还没有学习计划',
            message: '选一个领域和深度，定好什么时候开始。',
            actionLabel: '建第一条计划',
            actionKey: const Key('add_first_plan'),
            onAction: widget.onAdd,
          )
        else ...[
          if (ready.isNotEmpty) ...[
            SectionHeader(title: '可以开始', note: '${ready.length} 条'),
            const SizedBox(height: 10),
            for (final plan in ready) ...[
              _planCard(context, plan, now),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 6),
          ],
          if (upcoming.isNotEmpty) ...[
            SectionHeader(title: '接下来', note: '${upcoming.length} 条'),
            const SizedBox(height: 10),
            for (final plan in upcoming) ...[
              _planCard(context, plan, now),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 6),
          ],
          if (done.isNotEmpty) ...[
            _doneToggle(context, done.length),
            if (_showDone) ...[
              const SizedBox(height: 6),
              for (final plan in done) ...[
                _planCard(context, plan, now),
                const SizedBox(height: 10),
              ],
            ],
          ],
          const SizedBox(height: 6),
          Text(
            '提醒只在应用打开时出现，点开计划就能直接开始。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  /// 顶部的一项计数：数字加名称，颜色区分状态。
  Widget _statCard(
    BuildContext context,
    String label,
    int count,
    Color color,
  ) {
    final text = Theme.of(context).textTheme;
    return PaperCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        children: [
          Text(
            '$count',
            style: text.titleMedium?.copyWith(
              fontSize: 24,
              color: color,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: text.bodySmall),
        ],
      ),
    );
  }

  /// 已完成计划的折叠行：默认收起，点一下才展开。
  Widget _doneToggle(BuildContext context, int count) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: const Key('plan_done_toggle'),
        onPressed: () => setState(() => _showDone = !_showDone),
        icon: Icon(
          _showDone ? Icons.expand_less : Icons.expand_more,
          size: 18,
          color: paperInkSoft,
        ),
        label: Text(
          _showDone ? '收起已完成 $count 条' : '已完成 $count 条 · 展开',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        style: TextButton.styleFrom(foregroundColor: paperInkSoft),
      ),
    );
  }

  /// 一条计划卡片，菜单里可以标记完成或删除。
  Widget _planCard(BuildContext context, StudyPlan plan, DateTime now) {
    return PlanCard(
      key: Key('plan_${plan.id}'),
      plan: plan,
      graph: widget.graph,
      band: widget.band,
      now: now,
      onTap: () => widget.onOpen(plan),
      onToggleDone: widget.onToggleDone,
      onDelete: widget.onDelete,
    );
  }
}
