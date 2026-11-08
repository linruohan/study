import '../archive/learning_record.dart';
import 'mastery.dart';

/// 学习者模型：只根据本机记录统计每个概念练过几次。
///
/// 没有账号，也不上传。掌握概率的复杂版本以后可以替换这一层。
class LearnerState {
  LearnerState(this.counts);

  /// 概念 id → 本机练习次数。
  final Map<String, int> counts;

  /// 熟练集合只第一次用到时算一遍；档案不变时不用重复计算。
  Set<String>? _readyIds;

  /// 从档案记录里统计；只认带 conceptId 的记录。
  factory LearnerState.fromRecords(Iterable<LearningRecord> records) {
    final counts = <String, int>{};
    for (final record in records) {
      final conceptId = record.conceptId;
      if (conceptId == null) {
        continue;
      }
      counts[conceptId] = (counts[conceptId] ?? 0) + 1;
    }
    return LearnerState(counts);
  }

  /// 某概念的当前档位；没练过返回 null。
  MasteryTier? tierOf(String conceptId) {
    final count = counts[conceptId];
    if (count == null || count <= 0) {
      return null;
    }
    return tierFromCount(count);
  }

  /// 某概念的练习次数。
  int practiceCount(String conceptId) => counts[conceptId] ?? 0;

  /// 已到达熟练的概念 id，作为解锁下一项的依据。
  Set<String> get readyIds {
    return _readyIds ??= {
      for (final entry in counts.entries)
        if (tierFromCount(entry.value).unlocksNext) entry.key,
    };
  }
}
