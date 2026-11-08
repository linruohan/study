/// 学习计划的方向：先简单了解，还是走完整条阶梯深入学习。
enum PlanDepth {
  brief('简单了解', '先看最浅的一两步，知道它是什么。'),
  deep('深入学习', '从最浅走到最深，一格一格练到熟练。');

  const PlanDepth(this.label, this.description);

  /// 显示名称。
  final String label;

  /// 选择时的一句话说明。
  final String description;

  /// 这一方向在阶梯上的最深层级；null 表示不设上限。
  int? get maxDepth {
    return switch (this) {
      PlanDepth.brief => 1,
      PlanDepth.deep => null,
    };
  }

  /// 由存档里的名称找回方向；未知值返回 null。
  static PlanDepth? fromName(String? name) {
    for (final depth in PlanDepth.values) {
      if (depth.name == name) {
        return depth;
      }
    }
    return null;
  }
}

/// 一条本机学习计划：在某个时间，学某个领域的某个深度。
///
/// 计划只存在本机，不上传；到点提醒只在应用打开时出现。
class StudyPlan {
  const StudyPlan({
    required this.id,
    required this.domainId,
    required this.depth,
    required this.startAt,
    this.remind = true,
    this.done = false,
    this.remindedAt,
    this.snoozedUntil,
  });

  /// 稳定标识，用于列表更新与删除。
  final String id;

  /// 要学的领域 id。
  final String domainId;

  /// 简单了解或深入学习。
  final PlanDepth depth;

  /// 计划开始的时间。
  final DateTime startAt;

  /// 到时间是否提醒。
  final bool remind;

  /// 是否已经完成。
  final bool done;

  /// 已经提醒过的时间；null 表示还没提醒，避免重复弹窗。
  final DateTime? remindedAt;

  /// 点了「稍后」之后的新提醒时间；到这之前不再弹。
  final DateTime? snoozedUntil;

  /// 到时间没有；用于列表状态与提醒判断。
  bool due(DateTime now) => !startAt.isAfter(now);

  /// 只改需要改的字段，其余原样保留。
  StudyPlan copyWith({
    PlanDepth? depth,
    DateTime? startAt,
    bool? remind,
    bool? done,
    DateTime? remindedAt,
    DateTime? snoozedUntil,
  }) {
    return StudyPlan(
      id: id,
      domainId: domainId,
      depth: depth ?? this.depth,
      startAt: startAt ?? this.startAt,
      remind: remind ?? this.remind,
      done: done ?? this.done,
      remindedAt: remindedAt ?? this.remindedAt,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'domainId': domainId,
      'depth': depth.name,
      'startAt': startAt.toIso8601String(),
      'remind': remind,
      'done': done,
      if (remindedAt != null) 'remindedAt': remindedAt!.toIso8601String(),
      if (snoozedUntil != null) 'snoozedUntil': snoozedUntil!.toIso8601String(),
    };
  }

  /// 读取一条计划；字段缺失或损坏时返回 null，让坏数据被跳过。
  static StudyPlan? fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final domainId = json['domainId'];
    final depth = PlanDepth.fromName(json['depth'] as String?);
    final startAt = DateTime.tryParse(json['startAt'] as String? ?? '');
    if (id is! String || domainId is! String || depth == null || startAt == null) {
      return null;
    }
    final remindedRaw = json['remindedAt'] as String?;
    final snoozedRaw = json['snoozedUntil'] as String?;
    return StudyPlan(
      id: id,
      domainId: domainId,
      depth: depth,
      startAt: startAt,
      remind: json['remind'] as bool? ?? true,
      done: json['done'] as bool? ?? false,
      remindedAt: remindedRaw == null ? null : DateTime.tryParse(remindedRaw),
      snoozedUntil: snoozedRaw == null ? null : DateTime.tryParse(snoozedRaw),
    );
  }
}
