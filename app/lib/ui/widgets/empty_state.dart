import 'package:flutter/material.dart';

import '../theme.dart';

/// 空状态纸卡：图标、一句标题、一句解释，必要时给一个动作。
///
/// 每个入口的「还没有内容」都长这样，避免各页自己拼一份。
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionKey,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(20, 26, 20, 26),
  });

  /// 顶部的线性图标。
  final IconData icon;

  /// 一句标题，例如「还没有学习计划」。
  final String title;

  /// 一句解释，说清下一步做什么。
  final String message;

  /// 按钮文案；为空时不显示按钮。
  final String? actionLabel;

  /// 按钮的测试标识。
  final Key? actionKey;

  /// 点按钮时执行的动作。
  final VoidCallback? onAction;

  /// 纸卡内边距，个别页面可以改小一点。
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PaperCard(
      padding: padding,
      child: Column(
        children: [
          Icon(icon, size: 32, color: paperInkSoft),
          const SizedBox(height: 12),
          Text(title, style: text.titleMedium),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: text.bodySmall,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            TextButton(
              key: actionKey,
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
