import 'package:flutter/material.dart';

import '../knowledge/age_band.dart';
import '../knowledge/concept.dart';
import '../knowledge/domain.dart';
import '../knowledge/knowledge_graph.dart';
import '../learning/learner_state.dart';
import 'theme.dart';

/// 知识库入口：按学习程度分三个标签，标签内再按领域分组。
///
/// 标签状态由首页保存，返回详情页后仍停在原来的那一组。
class LibraryView extends StatelessWidget {
  const LibraryView({
    super.key,
    required this.graph,
    required this.band,
    required this.learner,
    required this.tab,
    required this.onSelectTab,
    required this.onOpen,
  });

  final KnowledgeGraph graph;
  final AgeBand band;
  final LearnerState learner;

  /// 当前标签：0 未开始、1 学习中、2 已掌握。
  final int tab;

  final ValueChanged<int> onSelectTab;
  final void Function(Concept concept, LearningDomain domain) onOpen;

  /// 三个程度标签的名称。
  static const _tabTitles = ['未开始', '学习中', '已掌握'];

  /// 判断某个概念属于哪个标签：0 未开始、1 尝试与熟悉、2 熟练与掌握。
  int _groupOf(Concept concept) {
    final tier = learner.tierOf(concept.id);
    if (tier == null) {
      return 0;
    }
    if (tier.unlocksNext) {
      return 2;
    }
    return 1;
  }

  /// 当前标签下每个领域各自有哪些概念。
  List<({LearningDomain domain, List<Concept> concepts})> _sections() {
    final sections = <({LearningDomain domain, List<Concept> concepts})>[];
    for (final domain in graph.domainsFor(band)) {
      final concepts = domain
          .conceptsFor(band)
          .where((concept) => _groupOf(concept) == tab)
          .toList();
      if (tab == 1) {
        // 「学习中」按练过的次数排：越接近下一档的排前面，同次数先看浅的一格。
        concepts.sort((a, b) {
          final byCount =
              learner.practiceCount(b.id) - learner.practiceCount(a.id);
          if (byCount != 0) {
            return byCount;
          }
          final byDepth = a.depth.compareTo(b.depth);
          if (byDepth != 0) {
            return byDepth;
          }
          return a.id.compareTo(b.id);
        });
      } else if (tab == 0) {
        // 「未开始」先给前置已练熟的格子，被挡住的排在后面，不让人白点。
        final ready = learner.readyIds;
        concepts.sort((a, b) {
          final aOpen = graph.unlocked(a, ready, band);
          final bOpen = graph.unlocked(b, ready, band);
          if (aOpen != bOpen) {
            return aOpen ? -1 : 1;
          }
          final byDepth = a.depth.compareTo(b.depth);
          if (byDepth != 0) {
            return byDepth;
          }
          return a.id.compareTo(b.id);
        });
      }
      if (concepts.isNotEmpty) {
        sections.add((domain: domain, concepts: concepts));
      }
    }
    return sections;
  }

  /// 每个标签下各有多少个知识点，显示在标签上。
  int _countOf(int target) {
    var total = 0;
    for (final domain in graph.domainsFor(band)) {
      for (final concept in domain.conceptsFor(band)) {
        if (_groupOf(concept) == target) {
          total++;
        }
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final sections = _sections();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Text('知识库', style: text.titleMedium),
        const SizedBox(height: 6),
        Text(
          '按学习的程度收在一起。点一条，看它讲什么，也可以加入学习计划。',
          style: text.bodySmall,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            for (var index = 0; index < _tabTitles.length; index++) ...[
              Expanded(child: _tabCard(context, index)),
              if (index != _tabTitles.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 18),
        if (sections.isEmpty)
          _empty(context)
        else
          for (final section in sections) ...[
            _sectionHeader(context, section.domain, section.concepts.length),
            const SizedBox(height: 10),
            for (final concept in section.concepts) ...[
              _knowledgeCard(context, concept, section.domain),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  /// 一个程度标签：名称加数量，选中时赭石底色。
  Widget _tabCard(BuildContext context, int index) {
    final text = Theme.of(context).textTheme;
    final selected = index == tab;
    return PaperCard(
      key: Key('library_tab_$index'),
      onTap: () => onSelectTab(index),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      color: selected ? paperOchre.withValues(alpha: 0.08) : paperSurface,
      child: Column(
        children: [
          Text(
            _tabTitles[index],
            style: text.titleMedium?.copyWith(
              fontSize: 15,
              color: selected ? paperOchre : paperInk,
            ),
          ),
          const SizedBox(height: 4),
          Text('${_countOf(index)} 条', style: text.bodySmall),
        ],
      ),
    );
  }

  /// 领域分组标题：符号、名称和条数，右侧再带一句整体熟练进度。
  Widget _sectionHeader(
    BuildContext context,
    LearningDomain domain,
    int count,
  ) {
    final text = Theme.of(context).textTheme;
    final total = domain.conceptsFor(band).length;
    final ready = graph.readyCount(domain, band, learner.readyIds);
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: domain.color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              domain.glyph,
              style: TextStyle(fontSize: 14, color: domain.color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          band.showsSubjectNames ? domain.name : '现在可以学',
          style: text.titleMedium,
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('$count 条', style: text.bodySmall),
            Text('熟练 $ready/$total', style: text.bodySmall),
          ],
        ),
      ],
    );
  }

  /// 一条知识：名称加一句简介，点开看详情。
  Widget _knowledgeCard(
    BuildContext context,
    Concept concept,
    LearningDomain domain,
  ) {
    final text = Theme.of(context).textTheme;
    final variant = concept.variantFor(band);
    final tier = learner.tierOf(concept.id);
    // 还没开始又缺前置时，卡片上直接说清楚先学哪一类，别让人白点。
    final locked =
        tier == null && !graph.unlocked(concept, learner.readyIds, band);
    return PaperCard(
      key: Key('knowledge_${concept.id}'),
      onTap: () => onOpen(concept, domain),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: domain.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                variant.glyph ?? domain.glyph,
                style: TextStyle(fontSize: 22, color: domain.color),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(variant.topic, style: text.titleMedium),
                const SizedBox(height: 4),
                Text(
                  variant.doing,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          MasteryPill(
            label: locked ? '先学前一项' : (tier?.label ?? '未开始'),
            color: locked
                ? paperStone
                : (tier == null
                    ? paperInkSoft
                    : (tier.unlocksNext ? paperOchre : paperInkSoft)),
          ),
        ],
      ),
    );
  }

  /// 某个标签下没有知识时的提示。
  Widget _empty(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PaperCard(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      child: Column(
        children: [
          const Icon(Icons.menu_book_outlined, size: 34, color: paperInkSoft),
          const SizedBox(height: 12),
          Text('这一组还没有知识', style: text.titleMedium),
          const SizedBox(height: 6),
          Text(
            tab == 0
                ? '这一档的知识都已经开始学了。'
                : (tab == 1 ? '先在「未开始」里挑一条试试。' : '把一两条练到熟练，就会收到这里。'),
            textAlign: TextAlign.center,
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}
