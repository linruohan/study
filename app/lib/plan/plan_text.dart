/// 计划时间的说法：今天、明天、昨天，其余写月日与时刻。
String planTimeLabel(DateTime startAt, {DateTime? now}) {
  final base = now ?? DateTime.now();
  final today = DateTime(base.year, base.month, base.day);
  final day = DateTime(startAt.year, startAt.month, startAt.day);
  final diff = day.difference(today).inDays;
  final hour = startAt.hour.toString().padLeft(2, '0');
  final minute = startAt.minute.toString().padLeft(2, '0');
  final prefix = switch (diff) {
    0 => '今天',
    1 => '明天',
    -1 => '昨天',
    _ => '${startAt.month}月${startAt.day}日',
  };
  return '$prefix $hour:$minute';
}
