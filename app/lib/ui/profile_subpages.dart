import 'package:flutter/material.dart';

import '../app_brand.dart';
import '../archive/learning_record.dart';
import '../data/auth_session.dart';
import '../data/study_repository.dart';
import '../plan/study_plan.dart';
import 'profile_view.dart';
import 'theme.dart';
import 'widgets/glyph_badge.dart';
import 'widgets/page_header.dart';
import 'widgets/section_header.dart';
import 'widgets/setting_row.dart';

/// 今日有记录的天数连击（含今天；今天还没记就从昨天往前数）。
int streakDays(List<LearningRecord> records, DateTime now) {
  final days = <String>{
    for (final record in records) _dayKey(record.at),
  };
  var streak = 0;
  var cursor = DateTime(now.year, now.month, now.day);
  if (!days.contains(_dayKey(cursor))) {
    cursor = cursor.subtract(const Duration(days: 1));
  }
  while (days.contains(_dayKey(cursor))) {
    streak += 1;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

String _dayKey(DateTime time) =>
    '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';

List<LearningRecord> todayRecords(List<LearningRecord> records, DateTime now) {
  final key = _dayKey(now);
  return records.where((record) => _dayKey(record.at) == key).toList();
}

/// 「我的」详细信息页：头像与资料、学习成就、学分与勋章、动态。
class ProfileDetailPage extends StatelessWidget {
  const ProfileDetailPage({
    super.key,
    required this.records,
    required this.creditBalance,
    required this.plans,
  });

  final List<LearningRecord> records;
  final int creditBalance;
  final List<StudyPlan> plans;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final user = AuthSession.user;
    final username = user?.username ?? '本机学习者';
    final today = todayRecords(records, now).length;
    final streak = streakDays(records, now);
    final degree = AuthSession.instance.degree;
    return Scaffold(
      backgroundColor: paperSurface,
      appBar: AppBar(title: const Text('我的详细信息')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          PaperCard(
            child: Row(
              children: [
                const GlyphBadge(
                    icon: Icons.account_circle_outlined,
                    color: paperOchre,
                    size: 64,
                    fontSize: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(username, style: text.titleLarge),
                      const SizedBox(height: 4),
                      Text('未设置个性签名', style: text.bodySmall),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('编辑资料即将支持')),
                  ),
                  child: const Text('编辑资料'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionHeader(title: '学习成就'),
          const SizedBox(height: 8),
          PaperCard(
            child: Row(
              children: [
                _achievementTile(context, '今日学习', '$today 条'),
                _divider(),
                _achievementTile(context, '连续学习', '$streak 天'),
                _divider(),
                _achievementTile(context, '累计记录', '${records.length} 条'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: PaperCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text('学分', style: text.titleMedium),
                        const SizedBox(width: 8),
                        MasteryPill(label: degree.realmLabel, color: paperOchre),
                      ]),
                      const SizedBox(height: 6),
                      Text('$creditBalance 分', style: text.headlineSmall?.copyWith(color: paperOchre)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PaperCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('计划', style: text.titleMedium),
                      const SizedBox(height: 6),
                      Text('${plans.length} 项', style: text.headlineSmall),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SectionHeader(title: '动态'),
          const SizedBox(height: 8),
          if (records.isEmpty)
            PaperCard(child: Text('还没有学习记录。', style: text.bodyMedium))
          else
            ...[
              for (final record in records.take(10))
                PaperCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(record.body, style: text.bodyMedium),
                      const SizedBox(height: 4),
                      Text(
                        '${record.at.month}-${record.at.day.toString().padLeft(2, '0')} · ${record.source}',
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
            ],
        ],
      ),
    );
  }

  Widget _achievementTile(BuildContext context, String label, String value) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          Text(value, style: text.titleLarge?.copyWith(color: paperOchre)),
          const SizedBox(height: 4),
          Text(label, style: text.bodySmall),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 32,
        color: paperLine,
      );
}

/// 设置页：账号、隐私、主题、缓存、关于等。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.repository});

  final StudyRepository repository;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: paperSurface,
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          const SectionHeader(title: '账号'),
          const SizedBox(height: 8),
          PaperCard(
            padding: EdgeInsets.zero,
            child: SettingRow(
              key: const Key('settings_account'),
              icon: Icons.person_outline,
              title: AuthSession.user == null
                  ? '登录'
                  : '账号 · ${AuthSession.user!.username}',
              subtitle: AuthSession.user == null
                  ? '登录后才能修改知识内容'
                  : AuthSession.user!.isAdmin
                      ? '管理员'
                      : '普通用户（只读）',
              onTap: () => showAccountDialog(context),
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader(title: '通用'),
          const SizedBox(height: 8),
          PaperCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SettingRow(
                  icon: Icons.privacy_tip_outlined,
                  title: '隐私设置',
                  subtitle: '他人可见范围（学分、证书、勋章、最近学习、资料）',
                  onTap: () => _todo(context, '隐私设置'),
                ),
                const Divider(),
                SettingRow(
                  icon: Icons.palette_outlined,
                  title: '主题',
                  subtitle: '纸本主题（浅色）',
                  onTap: () => _todo(context, '主题切换'),
                ),
                const Divider(),
                SettingRow(
                  icon: Icons.system_update_outlined,
                  title: '软件升级',
                  subtitle: '检查新版本',
                  onTap: () => _todo(context, '软件升级'),
                ),
                const Divider(),
                SettingRow(
                  key: const Key('settings_clear_cache'),
                  icon: Icons.cleaning_services_outlined,
                  title: '清除缓存',
                  subtitle: '删除本机的离线数据缓存，联网后自动重建',
                  onTap: () async {
                    final cleared = await repository.clearLocalCache();
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          cleared ? '缓存已清除' : '有未同步的离线修改，暂不能清除缓存',
                        ),
                      ),
                    );
                  },
                ),
                const Divider(),
                SettingRow(
                  icon: Icons.info_outline,
                  title: '关于',
                  subtitle: AppBrand.englishName,
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(AppBrand.name),
                      content: Text('${AppBrand.slogan}\n\n'
                          '本地优先的学习档案工具：记录与知识库在自建服务端，'
                          '本机只留设备标识与缓存，不交给第三方。'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('知道了'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader(title: '合规信息'),
          const SizedBox(height: 8),
          PaperCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SettingRow(
                  icon: Icons.list_alt_outlined,
                  title: '个人信息收集列表',
                  subtitle: '本应用收集哪些个人信息',
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('个人信息收集列表'),
                      content: const Text(
                          '· 设备标识（UUID）：区分学习数据\n'
                          '· 学习记录（练习、观察、小测）：生成指导与成就\n'
                          '· 学习设置与计划：恢复学习进度\n'
                          '· 本机缓存文件：断网时兜底\n'
                          '· 账号信息（用户名、密码哈希）：登录与权限'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('知道了'),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                SettingRow(
                  icon: Icons.share_outlined,
                  title: '第三方信息共享清单',
                  subtitle: '当前没有与第三方共享数据',
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('第三方信息共享清单'),
                      content: const Text('当前没有与任何第三方共享你的学习数据。'
                          '档案可由你自行导出保存。'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('知道了'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('纸本风格 · 中文本地化', textAlign: TextAlign.center, style: text.bodySmall),
        ],
      ),
    );
  }

  void _todo(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature 即将支持')),
    );
  }
}

/// 通用空态页：笔记、下载、收藏等占位入口。
class PlaceholderListPage extends StatelessWidget {
  const PlaceholderListPage({
    super.key,
    required this.title,
    required this.hint,
    this.children,
  });

  final String title;
  final String hint;
  final List<Widget>? children;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final list = children;
    return Scaffold(
      backgroundColor: paperSurface,
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          PageHeader(title: title, subtitle: hint),
          const SizedBox(height: 16),
          if (list == null || list.isEmpty)
            PaperCard(child: Text('这里还没有内容。', style: text.bodyMedium))
          else
            ...list,
        ],
      ),
    );
  }
}

/// 最近学习：最近的练习与观察记录。
class RecentLearningPage extends StatelessWidget {
  const RecentLearningPage({super.key, required this.records});

  final List<LearningRecord> records;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: paperSurface,
      appBar: AppBar(title: const Text('最近学习')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          const PageHeader(
            title: '最近学习',
            subtitle: '最近的练习与观察，完整档案在「我的」页导出。',
          ),
          const SizedBox(height: 16),
          if (records.isEmpty)
            PaperCard(child: Text('还没有学习记录。', style: text.bodyMedium))
          else
            for (final record in records.take(30))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: PaperCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(record.body, style: text.bodyMedium),
                      const SizedBox(height: 4),
                      Text(
                        '${record.at.year}-${record.at.month.toString().padLeft(2, '0')}-${record.at.day.toString().padLeft(2, '0')} · ${record.subject} · ${record.source}',
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// 收藏 / 清单：当前就是学习计划簿。
class CollectionPage extends StatelessWidget {
  const CollectionPage({super.key, required this.plans});

  final List<StudyPlan> plans;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: paperSurface,
      appBar: AppBar(title: const Text('收藏 / 清单')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          const PageHeader(
            title: '收藏 / 清单',
            subtitle: '当前展示我的学习计划；完整管理在「规划」页。',
          ),
          const SizedBox(height: 16),
          if (plans.isEmpty)
            PaperCard(child: Text('还没有加入计划。', style: text.bodyMedium))
          else
            for (final plan in plans)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: PaperCard(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    '${plan.conceptId ?? plan.categoryId} · ${plan.degree?.label ?? ''}',
                    style: text.bodyMedium,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
