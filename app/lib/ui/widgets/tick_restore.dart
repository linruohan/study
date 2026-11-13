/// 勾选恢复：从档案记录里单遍扫描，按「学习程度 · 知识点」前缀匹配。
///
/// 以前每个知识点再 scan 一遍档案，知识点多了以后是 O(n²)；
/// 现在只扫描一次，命中就写进对应下标。
void restoreChecked({
  required Iterable<String> bodies,
  required String prefix,
  required void Function(int index, bool hit) onHit,
}) {
  final list = bodies.toList();
  for (final body in list) {
    for (var i = 0; i < list.length; i++) {
      final target = '${prefix}_$i';
      if (body == target || body.startsWith('$target ·')) {
        onHit(i, true);
      }
    }
  }
}
