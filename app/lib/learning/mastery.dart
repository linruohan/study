/// 技能四档：只在本人和监护人视图出现，不公开比较。
enum MasteryTier {
  attempt('尝试'),
  familiar('熟悉'),
  skilled('熟练'),
  mastered('掌握');

  const MasteryTier(this.label);

  /// 显示名称。
  final String label;

  /// 到达熟练才解锁下一项，符合「会了再往下」。
  bool get unlocksNext => index >= MasteryTier.skilled.index;
}

/// 由本机练习次数推出档位。
///
/// 这是占位规则：1 次尝试、2–3 次熟悉、4 次熟练、5 次及以上掌握。
/// 以后要换成按作答序列更新的掌握概率，只需替换此函数。
MasteryTier tierFromCount(int count) {
  if (count <= 1) {
    return MasteryTier.attempt;
  }
  if (count <= 3) {
    return MasteryTier.familiar;
  }
  if (count == 4) {
    return MasteryTier.skilled;
  }
  return MasteryTier.mastered;
}
