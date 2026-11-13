/// 消息来源；后续可继续扩充（如审核结果、学习成就）。
enum AppMessageKind {
  planReminder('计划提醒'),
  system('系统通知');

  const AppMessageKind(this.label);

  /// 界面上的中文分类名。
  final String label;
}

/// 应用内的一条消息。
///
/// 目前消息由界面按计划与系统事件即时生成，只保存「已读 id」，
/// 不额外落库；后续需要推送或持久化时再扩展存储层。
class AppMessage {
  const AppMessage({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.actionLabel,
  });

  /// 稳定标识，用来记录已读状态。
  final String id;

  /// 消息来源。
  final AppMessageKind kind;

  /// 一行标题。
  final String title;

  /// 补充说明。
  final String body;

  /// 产生时间，列表按它倒序。
  final DateTime createdAt;

  /// 需要处理时消息末尾显示的操作按钮文案；null 表示只看不动。
  final String? actionLabel;
}
