import 'package:flutter/material.dart';

import '../knowledge/age_band.dart';
import '../knowledge/knowledge_graph.dart';
import '../learning/achievements.dart';
import '../learning/learner_state.dart';
import '../plan/study_plan.dart';
import 'theme.dart';

/// 我的入口：等级、徽章和设置。
class ProfileView extends StatelessWidget {
  const ProfileView({
    super.key,
    required this.graph,
    required this.band,
    required this.learner,
    required this.plans,
    required this.recordCount,
    required this.exportPath,
    required this.onChangeBand,
    required this.onGuardian,
    required this.onExport,
  });

  final KnowledgeGraph graph;
  final AgeBand band;
  final LearnerState learner;
  final List<StudyPlan> plans;
  final int recordCount;
  final String? exportPath;
  final VoidCallback onChangeBand;
  final VoidCallback onGuardian;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final standings = buildStandings(graph: graph, band: band, learner: learner);
    final achievements = buildAchievements(
      graph: graph,
      band: band,
      learner: learner,
      plans: plans,
    );
    final earned = achievements.where((item) => item.earned).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Text('我的', style: text.titleMedium),
        const SizedBox(height: 6),
        Text('等级看的是每个领域学到多深；徽章看的是走过哪些路。',
            style: text.bodySmall),
        const SizedBox(height: 16),
        _identityCard(context, earned, achievements.length),
        const SizedBox(height: 22),
        Text('等级', style: text.titleMedium),
        const SizedBox(height: 6),
        Text('把一格练到熟练，就往上升一级。整个领域都到掌握，是专家级。',
            style: text.bodySmall),
        const SizedBox(height: 12),
        if (standings.isEmpty)
          PaperCard(child: Text('这一档还没有内容。', style: text.bodyMedium))
        else
          for (final standing in standings) ...[
            _standingCard(context, standing),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 12),
        Row(
          children: [
            Text('徽章', style: text.titleMedium),
            const Spacer(),
            Text('$earned/${achievements.length}', style: text.bodySmall),
          ],
        ),
        const SizedBox(height: 6),
        Text('没达成的也会写清条件，知道下一步往哪走。', style: text.bodySmall),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: achievements.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 230,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.5,
          ),
          itemBuilder: (context, index) => _badgeCard(context, achievements[index]),
        ),
        const SizedBox(height: 22),
        Text('设置', style: text.titleMedium),
        const SizedBox(height: 12),
        PaperCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _settingRow(
                context,
                key: const Key('profile_change_band'),
                icon: Icons.swap_horiz,
                title: '换年龄档',
                subtitle: '当前是 ${band.label}',
                onTap: onChangeBand,
              ),
              const Divider(),
              _settingRow(
                context,
                key: const Key('profile_guardian'),
                icon: Icons.visibility_outlined,
                title: '监护人记一条',
                subtitle: '本机记录 $recordCount 条',
                onTap: onGuardian,
              ),
              const Divider(),
              _settingRow(
                context,
                key: const Key('profile_export'),
                icon: Icons.download_outlined,
                title: '导出档案到本机',
                subtitle: exportPath ?? '把本机记录复制一份',
                onTap: onExport,
              ),
            ],
          ),
        ),
        if (exportPath != null) ...[
          const SizedBox(height: 8),
          Text(exportPath!, textAlign: TextAlign.center, style: text.bodySmall),
        ],
      ],
    );
  }

  /// 顶部身份卡：当前档位、记录条数和徽章数。
  Widget _identityCard(BuildContext context, int earned, int total) {
    final text = Theme.of(context).textTheme;
    return PaperCard(
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: paperOchre.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.account_circle_outlined, color: paperOchre, size: 28),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(band.label, style: text.titleMedium),
                const SizedBox(height: 4),
                Text(band.howToLearn, style: text.bodySmall),
                const SizedBox(height: 6),
                Text('记录 $recordCount 条 · 徽章 $earned/$total',
                    style: text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 一个领域的等级卡：名称、等级、熟练与掌握进度。
  Widget _standingCard(BuildContext context, DomainStanding standing) {
    final text = Theme.of(context).textTheme;
    final domain = standing.domain;
    final level = standing.level;
    return PaperCard(
      key: Key('standing_${domain.id}'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: domain.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
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
                Text(domain.name, style: text.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '熟练 ${standing.ready}/${standing.total} 步'
                  ' · 掌握 ${standing.mastered} 步',
                  style: text.bodySmall,
                ),
                const SizedBox(height: 8),
                // 熟练步数占本档总步数的比例，一眼看出离下一级还有多远。
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: standing.total == 0
                        ? 0
                        : standing.ready / standing.total,
                    minHeight: 4,
                    backgroundColor: paperLine,
                    valueColor: AlwaysStoppedAnimation<Color>(domain.color),
                  ),
                ),
              ],
            ),
          ),
          MasteryPill(
            label: level?.label ?? '还没开始',
            color: level == null ? paperStone : paperOchre,
          ),
        ],
      ),
    );
  }

  /// 一枚徽章：达成时亮起，未达成时写清条件。
  Widget _badgeCard(BuildContext context, Achievement achievement) {
    final text = Theme.of(context).textTheme;
    final color = achievement.earned ? paperOchre : paperInkSoft;
    return PaperCard(
      key: Key('badge_${achievement.id}'),
      onTap: () => _showBadge(context, achievement),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      color: achievement.earned
          ? paperOchre.withValues(alpha: 0.06)
          : paperSurface,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: achievement.earned ? 0.14 : 0.06),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                achievement.earned
                    ? Icons.workspace_premium
                    : Icons.lock_outline,
                color: color,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  achievement.title,
                  style: text.titleMedium?.copyWith(
                    fontSize: 15,
                    color: achievement.earned ? paperInk : paperInkSoft,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  achievement.progress ?? achievement.condition,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 点开一枚徽章：完整条件与当前进度，不用再被两行省略号截断。
  Future<void> _showBadge(
    BuildContext context,
    Achievement achievement,
  ) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final text = Theme.of(dialogContext).textTheme;
        return AlertDialog(
          key: const Key('badge_dialog'),
          backgroundColor: paperSurface,
          title: Row(
            children: [
              Icon(
                achievement.earned
                    ? Icons.workspace_premium
                    : Icons.lock_outline,
                color: achievement.earned ? paperOchre : paperInkSoft,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(achievement.title),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                achievement.earned ? '已经拿到这枚徽章。' : '还没拿到，条件是：',
                style: text.bodySmall,
              ),
              const SizedBox(height: 6),
              Text(achievement.condition, style: text.bodyMedium),
              if (achievement.progress != null) ...[
                const SizedBox(height: 10),
                Text('现在：${achievement.progress}', style: text.bodySmall),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('知道了'),
            ),
          ],
        );
      },
    );
  }

  /// 设置里的一行，点整行触发。
  Widget _settingRow(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      key: key,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Icon(icon, color: paperInkSoft, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: paperInkSoft, size: 20),
          ],
        ),
      ),
    );
  }
}
