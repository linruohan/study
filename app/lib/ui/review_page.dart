import 'package:flutter/material.dart';

import '../archive/local_archive.dart';
import '../knowledge/age_band.dart';
import '../knowledge/concept.dart';
import '../knowledge/domain.dart';
import '../learning/learner_state.dart';
import 'theme.dart';

/// 学完之后的测验：逐条问答，低龄档再由监护人确认。
class ReviewPage extends StatefulWidget {
  const ReviewPage({
    super.key,
    required this.archive,
    required this.band,
    required this.domain,
    this.maxDepth,
  });

  final LocalArchive archive;
  final AgeBand band;
  final LearningDomain domain;

  /// 计划只覆盖到这一层；null 表示整个领域。
  final int? maxDepth;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  LearnerState? _learner;
  final Set<String> _checked = {};
  final Set<String> _revealed = {};
  var _confirmed = false;
  var _submitting = false;

  /// 低龄档需要监护人确认，高年龄由本人确认。
  bool get _needsGuardian {
    return widget.band == AgeBand.toddler ||
        widget.band == AgeBand.lowerPrimary ||
        widget.band == AgeBand.upperPrimary;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final archive = await widget.archive.load();
    if (!mounted) {
      return;
    }
    setState(() => _learner = LearnerState.fromRecords(archive.records));
  }

  /// 本次计划里确实练过的概念，小测只问这些。
  List<Concept> get _learned {
    final learner = _learner;
    if (learner == null) {
      return const [];
    }
    return widget.domain
        .conceptsFor(widget.band)
        .where((concept) =>
            (widget.maxDepth == null || concept.depth <= widget.maxDepth!) &&
            learner.practiceCount(concept.id) > 0)
        .toList();
  }

  /// 每条都答出来了、也确认过了，才可以提交。
  bool get _canSubmit {
    final learned = _learned;
    return learned.isNotEmpty &&
        learned.every((concept) => _checked.contains(concept.id)) &&
        _confirmed;
  }

  /// 提交：每条再记一次练习，然后带着结果返回。
  Future<void> _submit() async {
    if (_submitting || !_canSubmit) {
      return;
    }
    setState(() => _submitting = true);
    for (final concept in _learned) {
      await widget.archive.addPractice(
        subject: widget.domain.name,
        body: '完成小测：${concept.variantFor(widget.band).topic}',
        conceptId: concept.id,
        domainId: widget.domain.id,
        ageBandId: widget.band.id,
      );
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final learned = _learned;
    return Scaffold(
      appBar: AppBar(title: const Text('小测')),
      body: SafeArea(
        child: _learner == null
            ? const Center(child: CircularProgressIndicator(color: paperOchre))
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  Text('学完这几步，答一答', style: text.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    _needsGuardian
                        ? '每题想一想、答出来；最后由监护人确认。答对答错都不打分。'
                        : '每题想一想、答出来；确认完成就可以提交。答对答错都不打分。',
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: 18),
                  if (learned.isEmpty)
                    _emptyCard(context)
                  else ...[
                    for (final concept in learned) ...[
                      _questionCard(context, concept),
                      const SizedBox(height: 12),
                    ],
                    PaperCard(
                      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _needsGuardian ? '监护人确认' : '我确认',
                                  style: text.titleMedium,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _needsGuardian
                                      ? '我确认他独立完成了这几步。'
                                      : '这几步我都自己做过一遍。',
                                  style: text.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            key: const Key('review_confirm'),
                            value: _confirmed,
                            activeTrackColor: paperOchre,
                            onChanged: (value) =>
                                setState(() => _confirmed = value),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      key: const Key('submit_review'),
                      onPressed: _canSubmit && !_submitting ? _submit : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: paperOchre,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(_submitting ? '正在记录…' : '提交小测'),
                    ),
                    if (!_canSubmit) ...[
                      const SizedBox(height: 8),
                      Text(
                        '把每题都勾上，再确认一次。',
                        textAlign: TextAlign.center,
                        style: text.bodySmall,
                      ),
                    ],
                  ],
                ],
              ),
      ),
    );
  }

  /// 一道题：提问、勾选、参考回应。
  Widget _questionCard(BuildContext context, Concept concept) {
    final text = Theme.of(context).textTheme;
    final variant = concept.variantFor(widget.band);
    final checked = _checked.contains(concept.id);
    final revealed = _revealed.contains(concept.id);
    return PaperCard(
      key: Key('review_question_${concept.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(variant.topic, style: text.titleMedium),
              ),
              MasteryPill(label: '第 ${concept.depth + 1} 层'),
            ],
          ),
          const SizedBox(height: 8),
          Text(variant.check, style: text.bodyMedium),
          const SizedBox(height: 8),
          if (revealed)
            Text(
              variant.answer,
              style: text.bodySmall?.copyWith(color: paperOchre),
            )
          else
            TextButton(
              onPressed: () => setState(() => _revealed.add(concept.id)),
              child: const Text('看一句回应'),
            ),
          const SizedBox(height: 4),
          InkWell(
            key: Key('review_check_${concept.id}'),
            onTap: () {
              setState(() {
                if (checked) {
                  _checked.remove(concept.id);
                } else {
                  _checked.add(concept.id);
                }
              });
            },
            child: Row(
              children: [
                Icon(
                  checked
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: checked ? paperOchre : paperInkSoft,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text('我答出来了', style: text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 还没练过任何一步时的说明。
  Widget _emptyCard(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PaperCard(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      child: Column(
        children: [
          const Icon(Icons.edit_note_outlined, size: 34, color: paperInkSoft),
          const SizedBox(height: 12),
          Text('还没有练过的步骤', style: text.titleMedium),
          const SizedBox(height: 6),
          Text(
            '先在这个领域里学完至少一步，再回来小测。',
            textAlign: TextAlign.center,
            style: text.bodySmall,
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('回去继续学'),
          ),
        ],
      ),
    );
  }
}
