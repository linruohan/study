import 'package:flutter/material.dart';

import '../archive/learning_record.dart';
import '../data/auth_api.dart';
import '../data/auth_session.dart';
import '../data/study_repository.dart';
import '../knowledge/age_band.dart';
import '../knowledge/knowledge_graph.dart';
import '../learning/achievements.dart';
import '../learning/learner_state.dart';
import '../plan/study_plan.dart';
import 'profile_subpages.dart';
import 'theme.dart';
import 'widgets/glyph_badge.dart';
import 'widgets/page_header.dart';
import 'widgets/section_header.dart';
import 'widgets/setting_row.dart';

/// 我的入口：基础信息、我的知识宫格、等级徽章与设置。
///
/// 结构按开发指导文档「我的」页面 UI 规格：
/// 上（基础信息卡，可点进详情）→ 中（我的知识宫格）→ 下（设置）。
class ProfileView extends StatefulWidget {
  const ProfileView({
    super.key,
    required this.repository,
    required this.graph,
    required this.band,
    required this.learner,
    required this.plans,
    required this.records,
    required this.recordCount,
    required this.exportPath,
    required this.onChangeBand,
    required this.onGuardian,
    required this.onExport,
    required this.onImport,
    required this.onSage,
  });

  final StudyRepository repository;
  final KnowledgeGraph graph;
  final AgeBand band;
  final LearnerState learner;
  final List<StudyPlan> plans;
  final List<LearningRecord> records;
  final int recordCount;
  final String? exportPath;
  final VoidCallback onChangeBand;
  final VoidCallback onGuardian;
  final VoidCallback onExport;
  final VoidCallback onImport;
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
        const SectionHeader(title: '我的知识'),
        const SizedBox(height: 8),
        _knowledgeGrid(context, achievements),
        const SizedBox(height: 20),
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
        const SizedBox(height: 20),
        _quickSection(context),
        const SizedBox(height: 8),
        _settingsEntry(context),
        if (widget.exportPath != null) ...[
          const SizedBox(height: 8),
          Text(widget.exportPath!, textAlign: TextAlign.center, style: text.bodySmall),
        ],
      ],
    );
  }

  /// 上部基础信息卡：头像、用户名、境界，四项数据各进各的详情。
  Widget _identityCard(BuildContext context, int earned, int total) {
    final text = Theme.of(context).textTheme;
    final user = AuthSession.user;
    final username = user?.username ?? '本机学习者';
    final degree = AuthSession.instance.degree;
    final today = todayRecords(widget.records, DateTime.now()).length;
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: const Key('profile_identity'),
            onTap: () => _openDetail(context),
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                const GlyphBadge(
                    icon: Icons.account_circle_outlined,
                    color: paperOchre,
                    size: 56,
                    fontSize: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(username,
                              style: text.titleMedium, overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 8),
                        MasteryPill(label: degree.realmLabel, color: paperOchre),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.band.label} · 记录 ${widget.recordCount} 条',
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
                _studentCardChip(context),
              ],
            ),
          ),
          const Divider(height: 20, color: paperLine),
          FutureBuilder<Map<String, dynamic>>(
            future: _creditsFuture,
            builder: (context, snapshot) {
              final data = snapshot.data ?? const {};
              final balance = (data['balance'] as num?)?.toInt() ?? 0;
              return Row(
                children: [
                  _statTile(context, '学分', '$balance', onTap: () => _showCreditsDetail(context)),
                  _statDivider(),
                  _statTile(context, '今日学习', '$today 条',
                      onTap: () => _push(context, RecentLearningPage(records: widget.records))),
                  _statDivider(),
                  _statTile(context, '勋章', '$earned',
                      onTap: () => _showBadgesSheet(context, total)),
                  _statDivider(),
                  _statTile(context, '证书', '0',
                      onTap: () => _push(
                        context,
                        const PlaceholderListPage(
                          title: '证书',
                          hint: '达到境界或完成分类后颁发，敬请期待。',
                        ),
                      )),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _studentCardChip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: paperOchre.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: paperOchre.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.school_outlined, size: 14, color: paperOchre),
          const SizedBox(width: 4),
          Text('学生证', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: paperOchre)),
        ],
      ),
    );
  }

  Widget _statTile(
    BuildContext context,
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Text(value, style: text.titleLarge?.copyWith(color: paperOchre)),
              const SizedBox(height: 2),
              Text(label, style: text.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statDivider() => Container(width: 1, height: 32, color: paperLine);

  Future<void> _openDetail(BuildContext context) async {
    final data = await _creditsFuture;
    final balance = (data['balance'] as num?)?.toInt() ?? 0;
    if (!context.mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileDetailPage(
          records: widget.records,
          creditBalance: balance,
          plans: widget.plans,
        ),
      ),
    );
    _reloadCredits();
  }

  Future<void> _push(BuildContext context, Widget page) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  void _showBadgesSheet(BuildContext context, int total) {
    final achievements = buildAchievements(
      graph: widget.graph,
      band: widget.band,
      learner: widget.learner,
      plans: widget.plans,
    );
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('勋章墙 · ${achievements.where((a) => a.earned).length}/$total',
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 10),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final achievement in achievements)
                      ListTile(
                        leading: Icon(
                          achievement.earned ? Icons.workspace_premium : Icons.lock_outline,
                          color: achievement.earned ? paperOchre : paperInkSoft,
                        ),
                        title: Text(achievement.title),
                        subtitle: Text(
                          achievement.earned ? '已达成' : achievement.condition,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 中部「我的知识」宫格：笔记、最近学习、下载、收藏/清单。
  Widget _knowledgeGrid(BuildContext context, List<Achievement> achievements) {
    return Row(
      children: [
        _gridTile(context, Icons.bookmark_border, '笔记', () {
          _push(
            context,
            const PlaceholderListPage(
              title: '笔记',
              hint: '学习笔记整理中，先在练习里记录吧。',
            ),
          );
        }),
        _gridTile(context, Icons.history, '最近学习', () {
          _push(context, RecentLearningPage(records: widget.records));
        }),
        _gridTile(context, Icons.download_outlined, '下载', () {
          _push(
            context,
            const PlaceholderListPage(
              title: '下载',
              hint: '离线内容下载即将支持。',
            ),
          );
        }),
        _gridTile(context, Icons.favorite_border, '收藏/清单', () {
          _push(context, CollectionPage(plans: widget.plans));
        }),
      ],
    );
  }

  Widget _gridTile(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Icon(icon, size: 26, color: paperInkSoft),
              const SizedBox(height: 6),
              Text(label, style: text.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  /// 快捷区：保留常用入口在本页，完整设置在设置页。
  Widget _quickSection(BuildContext context) {
    return PaperCard(
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
          const Divider(),
          SettingRow(
            key: const Key('profile_import'),
            icon: Icons.upload_outlined,
            title: '导入档案副本',
            subtitle: '从导出的副本恢复（覆盖当前档案）',
            onTap: widget.onImport,
          ),
        ],
      ),
    );
  }

  Widget _settingsEntry(BuildContext context) {
    return PaperCard(
      padding: EdgeInsets.zero,
      child: SettingRow(
        key: const Key('profile_settings'),
        icon: Icons.settings_outlined,
        title: '设置',
        subtitle: '账号、隐私、主题、清除缓存、关于',
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SettingsPage(repository: widget.repository),
            ),
          );
          _reloadCredits();
          if (mounted) {
            setState(() {});
          }
        },
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

/// 打开账号弹窗（登录 / 改密 / 退出 / 学位申请）；设置页与「我的」页共用。
Future<void> showAccountDialog(BuildContext context) async {
  await showDialog<void>(context: context, builder: (_) => const _AccountDialog());
}

/// 登录 / 账号管理弹窗：未登录时登录，已登录时改密、申请学位或退出。
class _AccountDialog extends StatefulWidget {
  const _AccountDialog();

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _oldPassword = TextEditingController();
  final _newPassword = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _degreeLabel;
  String? _applyRealm;

  @override
  void initState() {
    super.initState();
    _loadDegree();
  }

  Future<void> _loadDegree() async {
    if (AuthSession.user == null) {
      return;
    }
    try {
      await AuthSession.instance.loadDegree();
      if (mounted) {
        setState(() => _degreeLabel = AuthSession.instance.degree.realmLabel);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _degreeLabel = null);
      }
    }
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _oldPassword.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      setState(() {
        _error = '$error';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthSession.user;
    return AlertDialog(
      key: const Key('account_dialog'),
      title: Text(user == null ? '登录' : '账号 · ${user.username}'),
      content: user == null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('account_username'),
                  controller: _username,
                  decoration: const InputDecoration(labelText: '用户名'),
                  autofocus: true,
                ),
                TextField(
                  key: const Key('account_password'),
                  controller: _password,
                  decoration: const InputDecoration(labelText: '密码'),
                  obscureText: true,
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.isAdmin ? '角色：管理员（可修改知识内容）' : '角色：普通用户（只读）'),
                if (_degreeLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('境界：$_degreeLabel'),
                  ),
                if (user.mustChangePassword)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('正在使用默认密码，请尽快修改。', style: TextStyle(color: Colors.orange)),
                  ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('account_old_password'),
                  controller: _oldPassword,
                  decoration: const InputDecoration(labelText: '原密码'),
                  obscureText: true,
                ),
                TextField(
                  key: const Key('account_new_password'),
                  controller: _newPassword,
                  decoration: const InputDecoration(labelText: '新密码（至少 8 位）'),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                Text('申请提升境界（九境三阶，管理员审核）',
                    style: Theme.of(context).textTheme.bodySmall),
                DropdownButtonFormField<String>(
                  key: const Key('account_degree_realm'),
                  initialValue: _applyRealm,
                  hint: const Text('选择目标境界'),
                  items: [
                    for (final realm in kDegreeRealms)
                      DropdownMenuItem(value: realm, child: Text(kDegreeRealmLabels[realm] ?? realm)),
                  ],
                  onChanged: (value) => setState(() => _applyRealm = value),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
              ],
            ),
      actions: [
        if (user != null)
          TextButton(
            key: const Key('account_logout'),
            onPressed: _busy ? null : () => _run(() => AuthSession.instance.logout()),
            child: const Text('退出登录'),
          ),
        if (user != null)
          TextButton(
            key: const Key('account_change_password'),
            onPressed: _busy || _oldPassword.text.isEmpty || _newPassword.text.length < 8
                ? null
                : () => _run(() => AuthSession.instance.changePassword(
                      oldPassword: _oldPassword.text,
                      newPassword: _newPassword.text,
                    )),
            child: const Text('修改密码'),
          ),
        if (user != null)
          TextButton(
            key: const Key('account_apply_degree'),
            onPressed: _busy || _applyRealm == null
                ? null
                : () => _run(() => AuthSession.instance.applyForDegree(_applyRealm!)),
            child: const Text('提交学位申请'),
          ),
        if (user == null)
          TextButton(
            key: const Key('account_login'),
            onPressed: _busy || _username.text.isEmpty || _password.text.isEmpty
                ? null
                : () => _run(() => AuthSession.instance.login(_username.text, _password.text)),
            child: const Text('登录'),
          ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('关闭')),
      ],
    );
  }
}
