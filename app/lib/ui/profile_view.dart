import 'package:flutter/material.dart';

import '../data/study_repository.dart';
import '../knowledge/age_band.dart';
import '../knowledge/knowledge_graph.dart';
import '../learning/achievements.dart';
import '../learning/learner_state.dart';
import '../plan/study_plan.dart';
import 'theme.dart';
import 'widgets/glyph_badge.dart';
import 'widgets/page_header.dart';
import 'widgets/section_header.dart';
import 'widgets/setting_row.dart';

/// 我的入口：等级、徽章、积分与设置。
class ProfileView extends StatefulWidget {
  const ProfileView({
    super.key,
    required this.repository,
    required this.graph,
    required this.band,
    required this.learner,
    required this.plans,
    required this.recordCount,
    required this.exportPath,
    required this.onChangeBand,
    required this.onGuardian,
    required this.onExport,
    required this.onSage,
  });

  final StudyRepository repository;
  final KnowledgeGraph graph;
  final AgeBand band;
  final LearnerState learner;
  final List<StudyPlan> plans;
  final int recordCount;
  final String? exportPath;
  final VoidCallback onChangeBand;
  final VoidCallback onGuardian;
  final VoidCallback onExport;
  final VoidCallback onSage;

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  late Future<Map<String, dynamic>> _creditsFuture;

  @override
  void initState() {
    super.initState();
    _creditsFuture = widget.repository.fetchPointCredits();
  }

  Future<void> _reloadCredits() async {
    setState(() {
      _creditsFuture = widget.repository.fetchPointCredits();
    });
  }

  Future<void> _showCreditsDetail(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.65,
            child: FutureBuilder<Map<String, dynamic>>(
              future: widget.repository.fetchPointCredits(limit: 100),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: paperOchre));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('加载失败：${snapshot.error}'));
                }
                final data = snapshot.data ?? const {};
                final balance = (data['balance'] as num?)?.toInt() ?? 0;
                final items = (data['items'] is List) ? (data['items'] as List) : const [];
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('积分明细 · 余额 $balance', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Expanded(
                    child: items.isEmpty
                        ? const Center(child: Text('暂无积分记录'))
                        : ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final item = items[i] as Map? ?? const {};
                              final amount = (item['amount'] as num?)?.toInt() ?? 0;
                              final reason = item['reason'] as String? ?? '';
                              final at = item['createdAt'] as String? ?? '';
                              return PaperCard(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('+ $amount  $reason', style: Theme.of(context).textTheme.bodyMedium),
                                if (at.isNotEmpty) Text(at, style: Theme.of(context).textTheme.bodySmall),
                              ]));
                            },
                          ),
                  ),
                ]);
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final standings = buildStandings(graph: widget.graph, band: widget.band, learner: widget.learner);
    final achievements = buildAchievements(
      graph: widget.graph,
      band: widget.band,
      learner: widget.learner,
      plans: widget.plans,
    );
    final earned = achievements.where((item) => item.earned).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        const PageHeader(
          title: '我的',
          subtitle: '等级看每个领域学到多深；徽章看走过哪些路；积分来自纠错审核等贡献。',
        ),
        const SizedBox(height: 16),
        _identityCard(context, earned, achievements.length),
        const SizedBox(height: 16),
        _creditsCard(context),
        const SizedBox(height: 22),
        const SectionHeader(title: '等级'),
        const SizedBox(height: 6),
        Text(
          '把一格练到熟练，就往上升一级。整个领域都到掌握，是专家级。',
          style: text.bodySmall,
        ),
        const SizedBox(height: 12),
        if (standings.isEmpty)
          PaperCard(child: Text('这一档还没有内容。', style: text.bodyMedium))
        else
          for (final standing in standings) ...[
            _standingCard(context, standing),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 12),
        SectionHeader(
          title: '徽章',
          trailing: Text('$earned/${achievements.length}', style: text.bodySmall),
        ),
        const SizedBox(height: 6),
        Text('没达成的也会写清条件，知道下一步往哪走。', style: text.bodySmall),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 480) {
              return GridView.builder(
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
              );
            }
            return Column(
              children: [
                for (final achievement in achievements) _badgeCard(context, achievement),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        const SectionHeader(title: '设置'),
        const SizedBox(height: 12),
        PaperCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              SettingRow(
                key: const Key('profile_change_band'),
                icon: Icons.swap_horiz,
                title: '换年龄档',
                subtitle: '当前：${widget.band.label}',
                onTap: widget.onChangeBand,
              ),
              const Divider(),
              SettingRow(
                key: const Key('profile_sage'),
                icon: Icons.auto_stories_outlined,
                title: '智者 · 添加知识',
                subtitle: '提交知识或知识点、创建子类型，审批后进入知识库。',
                onTap: widget.onSage,
              ),
              const Divider(),
              SettingRow(
                key: const Key('profile_guardian'),
                icon: Icons.visibility_outlined,
                title: '监护人记一笔',
                subtitle: '本机记录 ${widget.recordCount} 条',
                onTap: widget.onGuardian,
              ),
              const Divider(),
              SettingRow(
                key: const Key('profile_export'),
                icon: Icons.download_outlined,
                title: '导出档案到本地',
                subtitle: widget.exportPath ?? '把本机记录复制一份',
                onTap: widget.onExport,
              ),
            ],
          ),
        ),
        if (widget.exportPath != null) ...[
          const SizedBox(height: 8),
          Text(widget.exportPath!, textAlign: TextAlign.center, style: text.bodySmall),
        ],
      ],
    );
  }

  Widget _creditsCard(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PaperCard(
      child: FutureBuilder<Map<String, dynamic>>(
        future: _creditsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Row(children: [
              const GlyphBadge(icon: Icons.stars_outlined, color: paperOchre, size: 44, fontSize: 22),
              const SizedBox(width: 12),
              Expanded(child: Text('正在加载积分…', style: text.bodyMedium)),
            ]);
          }
          if (snapshot.hasError) {
            return Row(children: [
              const GlyphBadge(icon: Icons.stars_outlined, color: paperInkSoft, size: 44, fontSize: 22),
              const SizedBox(width: 12),
              Expanded(child: Text('积分加载失败，可稍后重试。', style: text.bodySmall)),
              TextButton(onPressed: _reloadCredits, child: const Text('重试')),
            ]);
          }
          final data = snapshot.data ?? const {};
          final balance = (data['balance'] as num?)?.toInt() ?? 0;
          final items = (data['items'] is List) ? (data['items'] as List) : const [];
          final recent = items.take(3).toList();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const GlyphBadge(icon: Icons.stars, color: paperOchre, size: 44, fontSize: 22),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('贡献积分', style: text.titleMedium),
                Text('审核通过的知识点纠错等会获得积分', style: text.bodySmall),
              ])),
              Text('$balance', style: text.headlineSmall?.copyWith(color: paperOchre)),
              IconButton(onPressed: _reloadCredits, icon: const Icon(Icons.refresh, size: 18)),
              IconButton(onPressed: () => _showCreditsDetail(context), icon: const Icon(Icons.receipt_long_outlined, size: 18), tooltip: '查看明细'),
            ]),
            if (recent.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final item in recent)
                if (item is Map)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+${(item['amount'] as num?)?.toInt() ?? 0}  ${item['reason'] ?? ''}',
                      style: text.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => _showCreditsDetail(context), child: const Text('查看全部明细'))),
            ] else
              Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => _showCreditsDetail(context), child: const Text('查看明细'))),
          ]);
        },
      ),
    );
  }

  Widget _identityCard(BuildContext context, int earned, int total) {
    final text = Theme.of(context).textTheme;
    return PaperCard(
      child: Row(
        children: [
          GlyphBadge(icon: Icons.account_circle_outlined, color: paperOchre, size: 58, fontSize: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.band.label, style: text.titleMedium),
                const SizedBox(height: 4),
                Text(widget.band.howToLearn, style: text.bodySmall),
                const SizedBox(height: 6),
                Text('记录 ${widget.recordCount} 条 · 徽章 $earned/$total', style: text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _standingCard(BuildContext context, CategoryStanding standing) {
    final text = Theme.of(context).textTheme;
    final category = standing.category;
    final level = standing.level;
    return PaperCard(
      key: Key('standing_${category.id}'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          GlyphBadge(glyph: category.glyph, color: category.color, size: 44, fontSize: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category.displayNameFor(widget.band), style: text.titleMedium),
                const SizedBox(height: 4),
                Text('熟练 ${standing.ready}/${standing.total} · 掌握 ${standing.mastered} 个', style: text.bodySmall),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: standing.total == 0 ? 0 : standing.ready / standing.total,
                    minHeight: 4,
                    backgroundColor: paperLine,
                    valueColor: AlwaysStoppedAnimation<Color>(category.color),
                  ),
                ),
              ],
            ),
          ),
          MasteryPill(label: level?.label ?? '还没开始', color: level == null ? paperStone : paperOchre),
        ],
      ),
    );
  }

  Widget _badgeCard(BuildContext context, Achievement achievement) {
    final text = Theme.of(context).textTheme;
    final color = achievement.earned ? paperOchre : paperInkSoft;
    return PaperCard(
      key: Key('badge_${achievement.id}'),
      onTap: () => _showBadge(context, achievement),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      color: achievement.earned ? paperOchre.withValues(alpha: 0.06) : paperSurface,
      child: Row(
        children: [
          GlyphBadge(
            icon: achievement.earned ? Icons.workspace_premium : Icons.lock_outline,
            color: color,
            size: 38,
            fontSize: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  achievement.title,
                  style: text.titleMedium?.copyWith(fontSize: 15, color: achievement.earned ? paperInk : paperInkSoft),
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

  Future<void> _showBadge(BuildContext context, Achievement achievement) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final text = Theme.of(dialogContext).textTheme;
        return AlertDialog(
          key: const Key('badge_dialog'),
          title: Row(
            children: [
              Icon(achievement.earned ? Icons.workspace_premium : Icons.lock_outline,
                  color: achievement.earned ? paperOchre : paperInkSoft, size: 22),
              const SizedBox(width: 8),
              Text(achievement.title),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(achievement.earned ? '已经拿到这枚徽章。' : '还没拿到，条件是：', style: text.bodySmall),
              const SizedBox(height: 6),
              Text(achievement.condition, style: text.bodyMedium),
              if (achievement.progress != null) ...[
                const SizedBox(height: 10),
                Text('现在：${achievement.progress}', style: text.bodySmall),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('知道了')),
          ],
        );
      },
    );
  }
}
