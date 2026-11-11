import 'package:flutter/material.dart';

/// 区块小标题：标题、可选的一句补充数量，右侧可放一个动作。
///
/// 一页里会出现多次，统一字号与对齐，避免各页自己拼 Row。
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.note,
    this.trailing,
  });

  /// 区块名称，例如「可以开始」「下一条计划」。
  final String title;

  /// 紧跟标题的补充，例如「3 条」。
  final String? note;

  /// 右对齐的动作，例如「全部计划」按钮。
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Text(title, style: text.titleMedium),
        if (note != null) ...[
          const SizedBox(width: 8),
          Text(note!, style: text.bodySmall),
        ],
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}
