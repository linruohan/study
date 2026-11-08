import 'package:flutter/material.dart';

import '../knowledge/concept.dart';
import '../learning/ladder.dart';
import 'theme.dart';

/// 领域阶梯：从浅到深一行一格，标出状态，未解锁的行不能点。
class LadderList extends StatelessWidget {
  const LadderList({
    super.key,
    required this.entries,
    required this.domainColor,
    required this.onOpen,
  });

  final List<LadderEntry> entries;
  final Color domainColor;
  final ValueChanged<Concept> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < entries.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _row(context, entries[index], index),
          ),
      ],
    );
  }

  /// 一行阶梯：序号、这一档在学什么、状态，以及锁定说明。
  Widget _row(BuildContext context, LadderEntry entry, int index) {
    final text = Theme.of(context).textTheme;
    final canOpen = entry.canOpen;
    return PaperCard(
      onTap: canOpen ? () => onOpen(entry.concept) : null,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: canOpen
                  ? domainColor.withValues(alpha: 0.12)
                  : paperLine.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 14,
                  color: canOpen ? domainColor : paperInkSoft,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.variant.topic, style: text.titleMedium),
                const SizedBox(height: 4),
                Text(
                  canOpen ? entry.variant.doing : '先学完前一项，再打开这里。',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          MasteryPill(
            label: entry.status.label,
            color: _statusColor(entry.status, domainColor),
          ),
        ],
      ),
    );
  }

  /// 状态颜色：未解锁用浅灰，可学用领域色，熟练与掌握用赭石。
  Color _statusColor(LadderStatus status, Color accent) {
    return switch (status) {
      LadderStatus.locked => const Color(0xFFB3A897),
      LadderStatus.available => accent,
      LadderStatus.attempt || LadderStatus.familiar => paperStone,
      LadderStatus.skilled || LadderStatus.mastered => paperOchre,
    };
  }
}
