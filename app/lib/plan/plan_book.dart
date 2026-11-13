import 'package:flutter/foundation.dart';

import 'plan_store.dart';
import 'study_plan.dart';

/// 计划簿：把数据库里的计划读成一份内存清单，所有增删改都从这里走。
///
/// 界面只监听它，不用自己排序、也不用每次手工写回。
class PlanBook extends ChangeNotifier {
  PlanBook(this._store);

  final PlanStore _store;
  List<StudyPlan> _plans = const [];

  /// 全部计划，按开始时间从早到晚。
  List<StudyPlan> get plans => List.unmodifiable(_plans);

  /// 读本机计划；坏数据由存储层跳过，这里只负责排序与通知。
  Future<void> load() async {
    _plans = _sorted(await _store.load());
    notifyListeners();
  }

  /// 新增一条计划。
  Future<void> add(StudyPlan plan) async {
    await _commit([..._plans, plan]);
  }

  /// 删除一条计划。
  Future<void> remove(StudyPlan plan) async {
    await _commit([
      for (final item in _plans)
        if (item.id != plan.id) item,
    ]);
  }

  /// 标记完成或取消完成。
  Future<void> toggleDone(StudyPlan plan) async {
    await replace(plan.copyWith(done: !plan.done));
  }

  /// 把一条计划标成已完成。
  Future<void> markDone(StudyPlan plan) async {
    await replace(plan.copyWith(done: true));
  }

  /// 记下已经提醒过的时间，避免重复弹窗。
  Future<void> markReminded(StudyPlan plan, DateTime at) async {
    await replace(plan.copyWith(remindedAt: at));
  }

  /// 点「稍后」：到新时间之前不再提醒。
  Future<void> postpone(StudyPlan plan, DateTime until) async {
    await replace(plan.copyWith(snoozedUntil: until));
  }

  /// 用新状态替换同 id 的旧计划；找不到就忽略。
  Future<void> replace(StudyPlan plan) async {
    await _commit([
      for (final item in _plans)
        item.id == plan.id ? plan : item,
    ]);
  }

  /// 最早一条该提醒的计划；没有就返回 null。
  StudyPlan? firstDue(DateTime now) {
    for (final plan in _plans) {
      if (plan.done || !plan.remind || plan.remindedAt != null) {
        continue;
      }
      if (plan.snoozedUntil != null && plan.snoozedUntil!.isAfter(now)) {
        continue;
      }
      if (plan.startAt.isAfter(now)) {
        continue;
      }
      return plan;
    }
    return null;
  }

  /// 写入本机并通知界面；排序集中在这里做一次。
  Future<void> _commit(List<StudyPlan> next) async {
    _plans = _sorted(next);
    notifyListeners();
    await _store.save(_plans);
  }

  /// 按开始时间从早到晚排序。
  List<StudyPlan> _sorted(List<StudyPlan> items) {
    return [...items]..sort((a, b) => a.startAt.compareTo(b.startAt));
  }
}
