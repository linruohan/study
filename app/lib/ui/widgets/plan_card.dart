import 'package:flutter/material.dart';

import '../../knowledge/age_band.dart';
import '../../knowledge/knowledge_graph.dart';
import '../../plan/plan_text.dart';
import '../../plan/study_plan.dart';
import '../theme.dart';
import 'glyph_badge.dart';

/// 一条学习计划卡片：领域、方向、时间与状态，右侧可挂操作菜单。
///
/// 「规划」页的列表和「学习」页的下一条计划共用它，样式与状态色只此一份。
class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.plan,
    required this.graph,
    required this.band,
    required this.now,
    this.onTap,
    this.onToggleDone,
    this.onDelete,
  });

  final StudyPlan plan;
  final KnowledgeGraph graph;
  final AgeBand band;

  /// 用来判断「可以开始 / 待开始」，由调用方统一传入。
  final DateTime now;

  /// 点整张卡片的动作。
  final VoidCallback? onTap;

  /// 标记完成或取消完成；传入后右侧出现菜单。
  final void Function(StudyPlan plan)? onToggleDone;

  /// 删除计划；传入后右侧出现菜单。
  final void Function(StudyPlan plan)? onDelete;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final domain = graph.domainById(plan.domainId);
    final color = domain?.color ?? paperInkSoft;
    final started = plan.due(now);
    final statusLabel = plan.done ? '已完成' : (started ? '可以开始' : '待开始');
    final statusColor = plan.done
        ? paperInkSoft
        : (started ? paperOchre : paperStone);
    final name = domain == null
        ? '这个领域暂时没有了'
        : (domain.displayNameFor(band));
    final hasMenu = onToggleDone != null || onDelete != null;
    final timeLine = '${plan.depth.label} · ${planTimeLabel(plan.startAt, now: now)}'
        '${plan.remind && !plan.done ? ' · 到点提醒' : ''}';
    return PaperCard(
      onTap: domain == null ? null : onTap,
      padding: EdgeInsets.fromLTRB(16, 14, hasMenu ? 4 : 16, 14),
      child: Row(
        children: [
          GlyphBadge(
            glyph: domain?.glyph ?? '·',
            color: color,
            size: 44,
            fontSize: 20,
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
                        name,
                        style: text.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    MasteryPill(label: statusLabel, color: statusColor),
                  ],
                ),
                const SizedBox(height: 4),
                Text(timeLine, style: text.bodySmall),
              ],
            ),
          ),
          if (hasMenu) _menu(),
        ],
      ),
    );
  }

  /// 右侧操作菜单：标记完成或删除。
  Widget _menu() {
    return PopupMenuButton<String>(
      tooltip: '更多操作',
      onSelected: (value) {
        if (value == 'done') {
          onToggleDone?.call(plan);
        } else if (value == 'delete') {
          onDelete?.call(plan);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'done',
          child: Text(plan.done ? '取消完成' : '标记完成'),
        ),
        const PopupMenuItem(value: 'delete', child: Text('删除计划')),
      ],
    );
  }
}
