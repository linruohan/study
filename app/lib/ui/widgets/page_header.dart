import 'package:flutter/material.dart';

/// 页面顶部标题区：一行大标题（可带右侧动作）加一句说明。
///
/// 四个入口和二级页面都用它，保证标题的层级、间距和语气一致。
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  /// 页面名称，例如「规划」「知识库」。
  final String title;

  /// 一句说明，说清这一页能做什么。
  final String subtitle;

  /// 右侧动作，例如「新建」按钮；为空时只显示标题。
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: text.headlineSmall)),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 6),
        Text(subtitle, style: text.bodySmall),
      ],
    );
  }
}
