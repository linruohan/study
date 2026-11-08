import 'package:flutter/material.dart';

import '../archive/local_archive.dart';
import '../knowledge/age_band.dart';
import '../knowledge/concept.dart';
import '../knowledge/domain.dart';
import '../learning/learner_state.dart';
import '../learning/mastery.dart';
import 'theme.dart';

/// 概念学习页：读一句引导，做一步，留下一条本机记录。
///
/// 不做测验、不打分、不发奖励；做完只说一句「我能……」。
class ConceptPage extends StatefulWidget {
  const ConceptPage({
    super.key,
    required this.archive,
    required this.band,
    required this.domain,
    required this.concept,
  });

  final LocalArchive archive;
  final AgeBand band;
  final LearningDomain domain;
  final Concept concept;

  @override
  State<ConceptPage> createState() => _ConceptPageState();
}

class _ConceptPageState extends State<ConceptPage> {
  late final ConceptVariant _variant = widget.concept.variantFor(widget.band);
  var _done = false;
  var _saving = false;
  var _showAnswer = false;
  MasteryTier? _tier;

  /// 点一下图示：写一条带概念 id 的记录，再算出这一格升到了哪一档。
  Future<void> _complete() async {
    if (_done || _saving) {
      return;
    }
    setState(() => _saving = true);
    final saved = await widget.archive.addPractice(
      subject: widget.domain.name,
      body: _variant.doing,
      conceptId: widget.concept.id,
      domainId: widget.domain.id,
      ageBandId: widget.band.id,
    );
    if (!mounted) {
      return;
    }
    final learner = LearnerState.fromRecords(saved.records);
    setState(() {
      _saving = false;
      _done = true;
      _tier = learner.tierOf(widget.concept.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.band.showsSubjectNames ? widget.domain.name : '这一步'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            Text(_variant.topic, style: text.headlineMedium),
            if (_variant.note != null) ...[
              const SizedBox(height: 10),
              Text(_variant.note!, style: text.bodySmall),
            ],
            const SizedBox(height: 24),
            Center(
              child: GestureDetector(
                key: Key('touch_${widget.concept.id}'),
                behavior: HitTestBehavior.opaque,
                onTap: _complete,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  width: 208,
                  height: 208,
                  decoration: BoxDecoration(
                    color: _done
                        ? widget.domain.color.withValues(alpha: 0.8)
                        : widget.domain.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.domain.color.withValues(alpha: 0.22),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _variant.glyph ?? widget.domain.glyph,
                      style: const TextStyle(
                        fontSize: 76,
                        height: 1.1,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              _done ? _variant.praise : _variant.doing,
              textAlign: TextAlign.center,
              style: _done ? text.headlineSmall : text.bodyMedium,
            ),
            const SizedBox(height: 10),
            if (_done) ...[
              Center(
                child: MasteryPill(
                  label: _tier?.label ?? '尝试',
                  color: paperOchre,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '这一步记在本机档案里。',
                textAlign: TextAlign.center,
                style: text.bodySmall,
              ),
              const SizedBox(height: 18),
              _checkCard(context),
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('回到学习'),
              ),
            ] else ...[
              Text(
                '点一下图示，就算做完这一步。',
                textAlign: TextAlign.center,
                style: text.bodySmall,
              ),
              if (_saving) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(
                  minHeight: 2,
                  color: paperOchre,
                  backgroundColor: paperLine,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// 形成性评价：只用来想一想，不记分，也可以不回答。
  Widget _checkCard(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('想一想', style: text.titleMedium),
          const SizedBox(height: 6),
          Text(_variant.check, style: text.bodyMedium),
          const SizedBox(height: 8),
          if (_showAnswer)
            Text(
              _variant.answer,
              style: text.bodySmall?.copyWith(color: paperOchre),
            )
          else
            TextButton(
              onPressed: () => setState(() => _showAnswer = true),
              child: const Text('看一句回应'),
            ),
        ],
      ),
    );
  }
}
