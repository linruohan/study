import 'dart:async';

import 'package:flutter/material.dart';

import '../../knowledge/domain.dart';
import '../../knowledge/knowledge_graph.dart';
import '../../plan/plan_book.dart';
import '../../plan/study_plan.dart';

/// 到点提醒：盯着计划簿，时间一到就弹一次询问。
///
/// 自己不画界面，只把子页面原样包起来；弹窗关掉后再记「已提醒」或「稍后」。
class PlanReminder extends StatefulWidget {
  const PlanReminder({
    super.key,
    required this.book,
    required this.graph,
    required this.onStart,
    required this.child,
  });

  final PlanBook book;
  final KnowledgeGraph graph;

  /// 选「现在开始」后交给首页去导航。
  final void Function(StudyPlan plan, LearningDomain domain) onStart;

  final Widget child;

  @override
  State<PlanReminder> createState() => _PlanReminderState();
}

class _PlanReminderState extends State<PlanReminder> {
  Timer? _timer;
  var _open = false;

  @override
  void initState() {
    super.initState();
    widget.book.addListener(_scheduleCheck);
    // 应用一直开着时，每半分钟看一眼有没有到点的计划。
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
    _scheduleCheck();
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.book.removeListener(_scheduleCheck);
    super.dispose();
  }

  /// 计划一有变化就等下一帧再检查，避免在构建过程中弹窗。
  void _scheduleCheck() {
    if (!mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  /// 找到最早到点的一条，问一句现在开始还是稍后。
  Future<void> _check() async {
    if (_open || !mounted) {
      return;
    }
    // 用户正在别的页面（学习、详情）时不打断，回到首页后再说。
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      return;
    }
    final now = DateTime.now();
    final due = widget.book.firstDue(now);
    if (due == null) {
      return;
    }
    final domain = widget.graph.domainById(due.domainId);
    _open = true;
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('计划到时间了'),
        content: Text(
          '${domain?.name ?? '学习'} · ${due.depth.label}\n现在开始吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('snooze'),
            child: const Text('稍后'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('start'),
            child: const Text('现在开始'),
          ),
        ],
      ),
    );
    _open = false;
    if (!mounted) {
      return;
    }
    if (choice == 'start') {
      await widget.book.markReminded(due, now);
      if (mounted && domain != null) {
        widget.onStart(due, domain);
      }
      return;
    }
    // 点空白关掉也算「稍后」：推迟十分钟，不丢提醒也不算已经提醒过。
    await widget.book.postpone(due, now.add(const Duration(minutes: 10)));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
