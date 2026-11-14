import 'package:flutter/material.dart';

import '../knowledge/age_band.dart';
import '../knowledge/taxonomy.dart';
import '../knowledge/knowledge_graph.dart';
import '../plan/plan_text.dart';
import '../plan/study_plan.dart';
import 'theme.dart';
import 'widgets/glyph_badge.dart';
import 'widgets/section_header.dart';

/// 新建学习计划：选分类、选方向（简单了解或深入学习）、选开始时间与提醒。
class PlanEditorPage extends StatefulWidget {
  const PlanEditorPage({
    super.key,
    required this.graph,
    required this.band,
    this.now,
    this.initialCategoryId,
    this.initialDepth,
  });

  final KnowledgeGraph graph;
  final AgeBand band;

  /// 测试可注入当前时间；为空时用真实时间。
  final DateTime? now;

  /// 从某个知识点进来时，预先选好它的分类。
  final String? initialCategoryId;

  /// 从某个知识点进来时，预先选好的方向。
  final PlanDepth? initialDepth;

  @override
  State<PlanEditorPage> createState() => _PlanEditorPageState();
}

class _PlanEditorPageState extends State<PlanEditorPage> {
  late final DateTime _now = widget.now ?? DateTime.now();
  late final List<ScholarCategory> _categories = widget.graph.categoriesWithContent(widget.band);
  late String? _categoryId = widget.initialCategoryId ??
      (_categories.isEmpty ? null : _categories.first.id);
  late PlanDepth _depth = widget.initialDepth ?? PlanDepth.brief;
  late DateTime _startAt = _defaultStart();
  var _remind = true;

  /// 默认从下一个整半点开始，避免弹出页面就已经「到点」。
  DateTime _defaultStart() {
    final nextMinute = (_now.minute ~/ 30 + 1) * 30;
    return DateTime(_now.year, _now.month, _now.day, _now.hour)
        .add(Duration(minutes: nextMinute));
  }

  /// 现在开始：把开始时间设成当前注入时间，并默认提醒。
  void _startNow() {
    setState(() {
      _startAt = _now;
      _remind = true;
    });
  }

  /// 选日期，保留原来的时刻。
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startAt,
      firstDate: DateTime(_now.year, _now.month, _now.day),
      lastDate: _now.add(const Duration(days: 730)),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _startAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _startAt.hour,
        _startAt.minute,
      );
    });
  }

  /// 选时刻，保留原来的日期。
  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startAt),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _startAt = DateTime(
        _startAt.year,
        _startAt.month,
        _startAt.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  /// 保存计划，把整条计划交给首页写入本机。
  void _save() {
    final categoryId = _categoryId;
    if (categoryId == null) {
      return;
    }
    final stamp = widget.now?.microsecondsSinceEpoch ??
        DateTime.now().microsecondsSinceEpoch;
    Navigator.of(context).pop(
      StudyPlan(
        id: 'plan_$stamp',
        categoryId: categoryId,
        depth: _depth,
        startAt: _startAt,
        remind: _remind,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('新建学习计划')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const SectionHeader(title: '选一个分类'),
            const SizedBox(height: 6),
            Text('计划会从这一档的阶梯开始。', style: text.bodySmall),
            const SizedBox(height: 12),
            for (final category in _categories) ...[
              _categoryRow(context, category),
              const SizedBox(height: 10),
            ],
            if (_categories.isEmpty) ...[
              Text('这一档还没有可学的分类。', style: text.bodyMedium),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 14),
            const SectionHeader(title: '怎么学'),
            const SizedBox(height: 6),
            Text('简单了解只看前几格；深入学习走完整个阶梯。', style: text.bodySmall),
            const SizedBox(height: 12),
            for (final depth in PlanDepth.values) ...[
              _depthRow(context, depth),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 14),
            const SectionHeader(title: '什么时候开始'),
            const SizedBox(height: 12),
            _timeCard(context),
            const SizedBox(height: 12),
            PaperCard(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('到时间提醒我', style: text.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          '提醒只在应用打开时出现，不会发系统通知。',
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Switch(
                    value: _remind,
                    activeTrackColor: paperOchre,
                    onChanged: (value) => setState(() => _remind = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('save_plan'),
              onPressed: _categories.isEmpty ? null : _save,
              child: const Text('保存计划'),
            ),
          ],
        ),
      ),
    );
  }

  /// 分类一行：图标、名称、选中标记；点整行即选中。
  Widget _categoryRow(BuildContext context, ScholarCategory category) {
    final text = Theme.of(context).textTheme;
    final selected = category.id == _categoryId;
    return PaperCard(
      key: Key('plan_category_${category.id}'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      onTap: () => setState(() => _categoryId = category.id),
      child: Row(
        children: [
          GlyphBadge(
            glyph: category.glyph,
            color: category.color,
            size: 40,
            fontSize: 18,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              category.displayNameFor(widget.band),
              style: text.titleMedium,
            ),
          ),
          if (selected)
            const Icon(Icons.check_circle, color: paperOchre, size: 22)
          else
            const Icon(Icons.circle_outlined, color: paperLine, size: 22),
        ],
      ),
    );
  }

  /// 方向一行：名称、一句说明、选中标记。
  Widget _depthRow(BuildContext context, PlanDepth depth) {
    final text = Theme.of(context).textTheme;
    final selected = depth == _depth;
    return PaperCard(
      key: Key('plan_depth_${depth.name}'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      onTap: () => setState(() => _depth = depth),
      child: Row(
        children: [
          Icon(
            depth == PlanDepth.brief
                ? Icons.visibility_outlined
                : Icons.landscape_outlined,
            color: selected ? paperOchre : paperInkSoft,
            size: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(depth.label, style: text.titleMedium),
                const SizedBox(height: 4),
                Text(depth.description, style: text.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (selected)
            const Icon(Icons.check_circle, color: paperOchre, size: 22)
          else
            const Icon(Icons.circle_outlined, color: paperLine, size: 22),
        ],
      ),
    );
  }

  /// 开始时间卡片：一句时间说明，加上现在、改日期、改时刻三个入口。
  Widget _timeCard(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule_outlined, color: paperStone, size: 22),
              const SizedBox(width: 10),
              Text(planTimeLabel(_startAt, now: _now), style: text.titleMedium),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _startAt.isAfter(_now) ? '到时间会按提醒设置提醒你。' : '已经到时间，可以现在开始。',
            style: text.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              TextButton(onPressed: _startNow, child: const Text('现在')),
              TextButton(onPressed: _pickDate, child: const Text('改日期')),
              TextButton(onPressed: _pickTime, child: const Text('改时刻')),
            ],
          ),
        ],
      ),
    );
  }
}
