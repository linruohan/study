import 'package:flutter/material.dart';

import '../archive/local_archive.dart';
import '../knowledge/age_band.dart';
import '../knowledge/concept.dart';
import '../knowledge/domain.dart';
import '../knowledge/knowledge_graph.dart';
import '../learning/ladder.dart';
import '../learning/learner_state.dart';
import 'concept_page.dart';
import 'ladder_list.dart';
import 'widgets/page_header.dart';

/// 一个领域的完整阶梯：从浅到深，点开一格就学。
class DomainPage extends StatefulWidget {
  const DomainPage({
    super.key,
    required this.archive,
    required this.band,
    required this.domain,
    this.graph = KnowledgeGraph.defaults,
    this.maxDepth,
    this.onFinish,
  });

  final LocalArchive archive;
  final AgeBand band;
  final LearningDomain domain;
  final KnowledgeGraph graph;

  /// 只显示这一层及更浅的格子；null 表示走完整条阶梯。
  final int? maxDepth;

  /// 从计划进入时，底部给出「学完了，去做小测」；null 表示不显示。
  final VoidCallback? onFinish;

  @override
  State<DomainPage> createState() => _DomainPageState();
}

class _DomainPageState extends State<DomainPage> {
  LearnerState? _learner;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 每次从学习页回来都重新读档案，让阶梯上的状态跟着更新。
  Future<void> _load() async {
    final archive = await widget.archive.load();
    if (!mounted) {
      return;
    }
    setState(() => _learner = LearnerState.fromRecords(archive.records));
  }

  Future<void> _open(Concept concept) async {
    final domain = widget.domain;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConceptPage(
          archive: widget.archive,
          band: widget.band,
          domain: domain,
          concept: concept,
        ),
      ),
    );
    await _load();
  }

  /// 按计划方向裁剪阶梯：简单了解只到最浅一两格，深入学习看全部。
  List<LadderEntry> _visibleEntries(LearnerState learner) {
    final entries = buildLadder(
      graph: widget.graph,
      domain: widget.domain,
      band: widget.band,
      learner: learner,
    );
    final limit = widget.maxDepth;
    if (limit == null) {
      return entries;
    }
    return entries.where((entry) => entry.concept.depth <= limit).toList();
  }

  @override
  Widget build(BuildContext context) {
    final learner = _learner;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.band.showsSubjectNames ? widget.domain.name : '去看看'),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            widget.onFinish == null ? 32 : 110,
          ),
          children: [
            PageHeader(
              title: '从浅到深',
              subtitle: widget.maxDepth == null
                  ? '先学前一项。熟练一格，下一格才打开。'
                  : '简单了解：只看最浅的一两格。熟练一格，下一格才打开。',
            ),
            const SizedBox(height: 16),
            if (learner != null)
              LadderList(
                entries: _visibleEntries(learner),
                domainColor: widget.domain.color,
                onOpen: _open,
              ),
          ],
        ),
      ),
      bottomNavigationBar: widget.onFinish == null
          ? null
          : _finishBar(context),
    );
  }

  /// 底部完成栏：从计划进入时才出现，学完直接去小测。
  Widget _finishBar(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: FilledButton(
          key: const Key('finish_learning'),
          onPressed: widget.onFinish,
          child: const Text('学完了，去做小测'),
        ),
      ),
    );
  }
}
