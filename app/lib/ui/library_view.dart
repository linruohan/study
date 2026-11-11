import 'package:flutter/material.dart';

import '../knowledge/age_band.dart';
import '../knowledge/concept.dart';
import '../knowledge/domain.dart';
import '../knowledge/knowledge_graph.dart';
import '../knowledge/taxonomy.dart';
import '../learning/learner_state.dart';
import 'theme.dart';
import 'widgets/empty_state.dart';
import 'widgets/glyph_badge.dart';

/// 知识库入口：左侧是九类分类树，右侧是选中节点的知识列表。
///
/// 树的第一层是九类（以「人」为圆心的知识分类），第二层是各类下的领域。
/// 点类节点看该类全部知识；点领域节点看该领域的知识；
/// 点知识进入详情页。选中状态由首页持有，切页返回后仍停在原处。
class LibraryView extends StatelessWidget {
  const LibraryView({
    super.key,
    required this.graph,
    required this.band,
    required this.learner,
    required this.selection,
    required this.onSelectCategory,
    required this.onSelectDomain,
    required this.onOpen,
  });

  final KnowledgeGraph graph;
  final AgeBand band;
  final LearnerState learner;

  /// 当前树节点：类 id 或领域 id，二选一。
  final String? selection;

  final ValueChanged<ScholarCategory> onSelectCategory;
  final ValueChanged<LearningDomain> onSelectDomain;
  final void Function(Concept concept, LearningDomain domain) onOpen;

  /// 选中节点是不是某个领域；null 或空串默认选第一个有内容的类。
  bool _isDomainSelected(LearningDomain domain) => selection == domain.id;

  /// 当前该高亮的类：选中的领域所属的类，或选中的类本身。
  ScholarCategory _activeCategory(
    List<({ScholarCategory category, List<LearningDomain> domains})> sections,
  ) {
    for (final section in sections) {
      if (section.category.id == selection) {
        return section.category;
      }
      for (final domain in section.domains) {
        if (domain.id == selection) {
          return section.category;
        }
      }
    }
    return sections
        .firstWhere((section) => section.domains.isNotEmpty)
        .category;
  }

  /// 右侧要显示的知识：按当前选中节点收拢。
  List<({LearningDomain domain, Concept concept})> _rows(
    List<({ScholarCategory category, List<LearningDomain> domains})> sections,
    ScholarCategory active,
  ) {
    final rows = <({LearningDomain domain, Concept concept})>[];
    for (final section in sections) {
      final targets = section.category.id == active.id
          ? (selection != null && section.domains.any((d) => d.id == selection)
              ? section.domains.where((d) => d.id == selection).toList()
              : section.domains)
          : const <LearningDomain>[];
      for (final domain in targets) {
        for (final concept in domain.conceptsFor(band)) {
          rows.add((domain: domain, concept: concept));
        }
      }
    }
    return rows;
  }

  /// 一条知识的掌握状态：0 未开始、1 学习中、2 已掌握。
  int _groupOf(Concept concept) {
    final tier = learner.tierOf(concept.id);
    if (tier == null) {
      return 0;
    }
    return tier.unlocksNext ? 2 : 1;
  }

  @override
  Widget build(BuildContext context) {
    final sections = graph.categoriesFor(band);
    final active = _activeCategory(sections);
    final rows = _rows(sections, active);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 216,
            child: _treePanel(context, sections, active),
          ),
          const SizedBox(width: 16),
          Expanded(child: _detailPanel(context, active, rows)),
        ],
      ),
    );
  }

  /// 左侧树：九类为固定骨架，领域挂在类下，展开状态跟着选中走。
  Widget _treePanel(
    BuildContext context,
    List<({ScholarCategory category, List<LearningDomain> domains})> sections,
    ScholarCategory active,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: paperSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: paperLine),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 10),
        children: [
          for (final section in sections) ...[
            _categoryTile(context, section, section.category == active),
            for (final domain in section.domains)
              if (section.category == active) _domainTile(context, domain),
          ],
        ],
      ),
    );
  }

  /// 类节点：符号、名称、领域计数，选中时淡赭底。
  Widget _categoryTile(
    BuildContext context,
    ({ScholarCategory category, List<LearningDomain> domains}) section,
    bool selected,
  ) {
    final text = Theme.of(context).textTheme;
    final category = section.category;
    return InkWell(
      key: Key('tree_category_${category.id}'),
      onTap: () => onSelectCategory(category),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? paperOchre.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            GlyphBadge(
              glyph: category.glyph,
              color: category.color,
              size: 30,
              fontSize: 14,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category.name, style: text.titleMedium),
                  Text(
                    category.question,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
            Text('${section.domains.length}', style: text.bodySmall),
          ],
        ),
      ),
    );
  }

  /// 领域子节点：缩进显示，点开看该领域的知识。
  Widget _domainTile(BuildContext context, LearningDomain domain) {
    final text = Theme.of(context).textTheme;
    final selected = _isDomainSelected(domain);
    return InkWell(
      key: Key('tree_domain_${domain.id}'),
      onTap: () => onSelectDomain(domain),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(left: 26, right: 8, bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? paperStone.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            GlyphBadge(
              glyph: domain.glyph,
              color: domain.color,
              size: 24,
              fontSize: 12,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                domain.name,
                style: text.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text('${domain.conceptsFor(band).length}', style: text.bodySmall),
          ],
        ),
      ),
    );
  }

  /// 右侧面板：当前节点下的知识卡片列表，顶部带一句该类回答的问题。
  Widget _detailPanel(
    BuildContext context,
    ScholarCategory active,
    List<({LearningDomain domain, Concept concept})> rows,
  ) {
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: paperSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: paperLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(active.name, style: text.headlineSmall),
                const SizedBox(height: 4),
                Text(active.question, style: text.bodySmall),
              ],
            ),
          ),
          const Divider(height: 1, color: paperLine),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: EmptyState(
                      icon: Icons.category_outlined,
                      title: '这一类还没有知识',
                      message: '新增领域时按九类归类，这里就会长出来。',
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
                    children: [
                      for (final row in rows) ...[
                        _knowledgeCard(context, row.concept, row.domain),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// 一条知识：名称加一句简介，点开看详情；右侧带掌握状态。
  Widget _knowledgeCard(
    BuildContext context,
    Concept concept,
    LearningDomain domain,
  ) {
    final text = Theme.of(context).textTheme;
    final variant = concept.variantFor(band);
    final tier = learner.tierOf(concept.id);
    final locked =
        tier == null && !graph.unlocked(concept, learner.readyIds, band);
    final group = _groupOf(concept);
    final statusLabel = locked
        ? '先学前一项'
        : switch (group) {
            0 => '未开始',
            1 => '学习中',
            _ => '已掌握',
          };
    final statusColor = locked
        ? paperStone
        : switch (group) {
            0 => paperInkSoft,
            1 => paperOchre,
            _ => paperInk,
          };
    return PaperCard(
      key: Key('knowledge_${concept.id}'),
      onTap: () => onOpen(concept, domain),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          GlyphBadge(
            glyph: variant.glyph ?? domain.glyph,
            color: domain.color,
            size: 46,
            rounded: true,
            fontSize: 22,
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
          MasteryPill(label: statusLabel, color: statusColor),
        ],
      ),
    );
  }
}
