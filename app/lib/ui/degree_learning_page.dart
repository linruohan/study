import 'package:flutter/material.dart';

import '../archive/archive_store.dart';
import '../knowledge/age_band.dart';
import '../knowledge/concept.dart';
import '../knowledge/domain.dart';
import '../knowledge/study_degree.dart';
import '../learning/mastery.dart';
import 'theme.dart';
import 'widgets/glyph_badge.dart';

/// 知识进度学习页：按加入计划时的学习程度，列出知识点逐条勾选。
///
/// 勾一条就往本机档案写一条带概念 id 的练习记录，所以：
/// 第一次勾选后知识变「学习中」，勾得越多掌握档越高；
/// 重进页面时按记录内容恢复勾选状态。
class DegreeLearningPage extends StatefulWidget {
  const DegreeLearningPage({
    super.key,
    required this.archive,
    required this.band,
    required this.domain,
    required this.concept,
    required this.degree,
  });

  final ArchiveStore archive;
  final AgeBand band;
  final LearningDomain domain;
  final Concept concept;

  /// 加入计划时选定的学习程度。
  final StudyDegree degree;

  @override
  State<DegreeLearningPage> createState() => _DegreeLearningPageState();
}

class _DegreeLearningPageState extends State<DegreeLearningPage> {
  late final ConceptVariant _variant = widget.concept.variantFor(widget.band);
  late final List<String> _points = _variant.pointsFor(widget.degree);
  MasteryTier? _tier;

  /// 知识点下标 → 本机是否已有这条勾选记录。
  late Map<int, bool> _checked;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _checked = {for (var i = 0; i < _points.length; i++) i: false};
    _restore();
  }

  /// 读档案，把已经勾过的知识点恢复出来。
  Future<void> _restore() async {
    final archive = await widget.archive.load();
    if (!mounted) {
      return;
    }
    setState(() {
      for (var i = 0; i < _points.length; i++) {
        _checked[i] = archive.records.any(
          (record) => _isPointRecord(record.body, i),
        );
      }
    });
  }

  /// 记录 body 是否对应第 [index] 个知识点。
  bool _isPointRecord(String body, int index) {
    final target = pointBody(_points[index]);
    // 历史记录可能把「做一做」的整句写进 body，用前缀匹配避免误判。
    return body == target || body.startsWith('$target ·');
  }

  /// 一条知识点勾选记录写进档案的 body。
  String pointBody(String point) => '${widget.degree.label} · $point';

  /// 勾选一个知识点：写一条练习记录，刷新掌握档。
  Future<void> _toggle(int index) async {
    if (_saving) {
      return;
    }
    if (_checked[index] == true) {
      return;
    }
    setState(() => _saving = true);
    final saved = await widget.archive.addPractice(
      subject: widget.domain.displayNameFor(widget.band),
      body: pointBody(_points[index]),
      conceptId: widget.concept.id,
      domainId: widget.domain.id,
      ageBandId: widget.band.id,
    );
    if (!mounted) {
      return;
    }
    var count = 0;
    for (final record in saved.records) {
      if (record.conceptId == widget.concept.id) {
        count++;
      }
    }
    setState(() {
      _saving = false;
      _checked[index] = true;
      _tier = tierFromCount(count);
    });
    // 最后一条勾完，给一句完成反馈；不弹窗，不另发奖励。
    if (_checked.values.every((value) => value) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '「${widget.degree.label}」的知识点都学完了',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final doneCount = _checked.values.where((value) => value).length;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.degree.label} · ${_variant.topic}'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Row(
                children: [
                  GlyphBadge(
                    glyph: _variant.glyph ?? widget.domain.glyph,
                    color: widget.domain.color,
                    size: 44,
                    rounded: true,
                    fontSize: 20,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.degree.label}程度 · $_variantTopic',
                          style: text.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '勾一条记一条，都勾完这一步就算走完。',
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: _points.isEmpty ? 0 : doneCount / _points.length,
                      minHeight: 4,
                      color: paperOchre,
                      backgroundColor: paperLine,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$doneCount/${_points.length}',
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                children: [
                  for (var i = 0; i < _points.length; i++) ...[
                    _pointCard(context, i),
                    const SizedBox(height: 10),
                  ],
                  if (_tier != null) ...[
                    const SizedBox(height: 4),
                    Center(
                      child: MasteryPill(
                        label: '当前掌握：${_tier!.label}',
                        color: paperOchre,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _variantTopic => _variant.topic;

  /// 一个知识点卡片：勾选框加文字；勾过就淡化并打勾。
  Widget _pointCard(BuildContext context, int index) {
    final text = Theme.of(context).textTheme;
    final checked = _checked[index] == true;
    return PaperCard(
      key: Key('degree_point_$index'),
      onTap: checked ? null : () => _toggle(index),
      padding: const EdgeInsets.all(14),
      color: checked ? paperOchre.withValues(alpha: 0.05) : null,
      child: Row(
        children: [
          Icon(
            checked ? Icons.check_circle : Icons.radio_button_unchecked,
            color: checked ? paperOchre : paperLine,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _points[index],
              style: text.bodyMedium?.copyWith(
                color: checked ? paperInkSoft : paperInk,
              ),
            ),
          ),
          if (_saving && !checked)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: paperOchre),
            ),
        ],
      ),
    );
  }
}
