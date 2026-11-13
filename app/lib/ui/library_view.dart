import 'package:flutter/material.dart';

import '../knowledge/age_band.dart';
import '../knowledge/concept.dart';
import '../knowledge/domain.dart';
import '../knowledge/knowledge_catalog.dart';
import '../knowledge/knowledge_graph.dart';
import '../knowledge/taxonomy.dart';
import '../learning/learner_state.dart';
import 'theme.dart';
import 'widgets/empty_state.dart';
import 'widgets/glyph_badge.dart';

const _twoPaneMinWidth = 760.0;

/// 知识库：左侧分类/子类型树（可嵌套），右侧显示选中节点下的知识。
class LibraryView extends StatelessWidget {
  const LibraryView({
    super.key,
    required this.graph,
    required this.band,
    required this.learner,
    required this.selection,
    required this.expandedIds,
    required this.onSelectCategory,
    required this.onToggleExpand,
    required this.onSelectDomain,
    required this.onOpen,
  });

  final KnowledgeGraph graph;
  final AgeBand band;
  final LearnerState learner;
  final String? selection;
  final Set<String> expandedIds;
  final ValueChanged<ScholarCategory> onSelectCategory;
  final ValueChanged<ScholarCategory> onToggleExpand;
  final ValueChanged<LearningDomain> onSelectDomain;
  final void Function(Concept concept, LearningDomain domain) onOpen;

  bool _isDomainSelected(LearningDomain domain) => selection == domain.id;

  ScholarCategory _activeCategory(List<ScholarCategory> roots) {
    if (selection != null) {
      final cat = graph.categoryById(selection!);
      if (cat != null) return cat;
      for (final c in graph.categories) {
        final domains = graph.directDomainsInCategory(c, band);
        if (domains.any((d) => d.id == selection)) return c;
      }
    }
    return roots.isNotEmpty ? roots.first : graph.categories.first;
  }

  List<({LearningDomain domain, Concept concept})> _rowsForCategory(ScholarCategory active) {
    // 若选中的是该分类下某个领域，只显示该领域
    if (selection != null) {
      final selectedDomain = graph.domainById(selection!);
      if (selectedDomain != null && selectedDomain.categoryId == active.id) {
        return [
          for (final concept in selectedDomain.conceptsFor(band))
            (domain: selectedDomain, concept: concept),
        ];
      }
    }
    // 否则显示该分类及其所有后代子分类下的直接领域知识
    final rows = <({LearningDomain domain, Concept concept})>[];
    void collect(ScholarCategory cat) {
      for (final domain in graph.directDomainsInCategory(cat, band)) {
        for (final concept in domain.conceptsFor(band)) {
          rows.add((domain: domain, concept: concept));
        }
      }
      for (final child in graph.childrenOf(cat.id)) {
        collect(child);
      }
    }
    collect(active);
    return rows;
  }

  int _groupOf(Concept concept) {
    final tier = learner.tierOf(concept.id);
    if (tier == null) return 0;
    return tier.unlocksNext ? 2 : 1;
  }

  String _creatorOf(Concept concept) {
    final catalog = KnowledgeCatalog.maybeInstance;
    if (catalog == null) return '';
    return catalog.sageCredits.creatorOfConcept(concept.id);
  }

  List<_TreeEntry> _visibleEntries() {
    final entries = <_TreeEntry>[];
    void walk(ScholarCategory cat, int depth) {
      final children = graph.childrenOf(cat.id);
      final domains = graph.directDomainsInCategory(cat, band);
      final hasChildren = children.isNotEmpty || domains.isNotEmpty;
      entries.add(_TreeEntry.category(cat, depth, hasChildren));
      if (expandedIds.contains(cat.id)) {
        for (final child in children) {
          walk(child, depth + 1);
        }
        for (final domain in domains) {
          entries.add(_TreeEntry.domain(domain, depth + 1));
        }
      }
    }
    for (final root in graph.rootCategories) {
      walk(root, 0);
    }
    // 兼容：若存在未挂到根树的分类（异常数据），也展示出来
    final seen = {for (final e in entries) if (e.category != null) e.category!.id};
    for (final cat in graph.categories) {
      if (cat.parentId != null && !seen.contains(cat.id)) {
        walk(cat, 0);
      }
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final roots = graph.rootCategories.isNotEmpty ? graph.rootCategories : graph.categories;
    final active = _activeCategory(roots);
    final rows = _rowsForCategory(active);
    final entries = _visibleEntries();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= _twoPaneMinWidth;
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 240, child: _treePanel(context, entries, active)),
                const SizedBox(width: 16),
                Expanded(child: _detailPanel(context, active, rows)),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _categoryStrip(context, roots, active),
              const SizedBox(height: 12),
              Expanded(child: _detailPanel(context, active, rows)),
            ],
          );
        },
      ),
    );
  }

  Widget _treePanel(BuildContext context, List<_TreeEntry> entries, ScholarCategory active) {
    return Container(
      decoration: BoxDecoration(
        color: paperSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: paperLine),
      ),
      child: ListView.builder(
        key: const PageStorageKey('library_tree'),
        padding: const EdgeInsets.symmetric(vertical: 10),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          if (entry.domain != null) {
            return _domainTile(context, entry.domain!, entry.depth);
          }
          return _categoryTile(context, entry.category!, entry.depth, entry.hasChildren, entry.category!.id == active.id);
        },
      ),
    );
  }

  Widget _categoryStrip(BuildContext context, List<ScholarCategory> roots, ScholarCategory active) {
    final activeRoot = _rootOf(active) ?? active;
    final domainTargets = graph.directDomainsInCategory(activeRoot, band);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 64,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            key: const PageStorageKey('library_strip'),
            padding: const EdgeInsets.symmetric(horizontal: 2),
            itemCount: roots.length,
            itemBuilder: (context, index) {
              final category = roots[index];
              final selected = category.id == activeRoot.id;
              final count = graph.directDomainsInCategory(category, band).length + graph.childrenOf(category.id).length;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: PaperCard(
                  key: Key('tree_category_${category.id}'),
                  onTap: () => onSelectCategory(category),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  color: selected ? paperOchre.withValues(alpha: 0.08) : paperSurface,
                  child: Row(
                    children: [
                      GlyphBadge(glyph: category.glyph, color: category.color, size: 28, fontSize: 13),
                      const SizedBox(width: 8),
                      Text(category.name, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(width: 4),
                      Text('$count', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (domainTargets.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              itemCount: domainTargets.length,
              itemBuilder: (context, index) {
                final domain = domainTargets[index];
                final selected = _isDomainSelected(domain);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: PaperCard(
                    key: Key('tree_domain_${domain.id}'),
                    onTap: () => onSelectDomain(domain),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    color: selected ? paperStone.withValues(alpha: 0.1) : paperSurface,
                    child: Row(
                      children: [
                        GlyphBadge(glyph: domain.glyph, color: domain.color, size: 22, fontSize: 11),
                        const SizedBox(width: 8),
                        Text(domain.displayNameFor(band), style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  ScholarCategory? _rootOf(ScholarCategory cat) {
    ScholarCategory? cur = cat;
    final seen = <String>{};
    while (cur != null && cur.parentId != null) {
      if (!seen.add(cur.id)) break;
      cur = graph.categoryById(cur.parentId!);
    }
    return cur;
  }

  Widget _categoryTile(BuildContext context, ScholarCategory category, int depth, bool hasChildren, bool selected) {
    final text = Theme.of(context).textTheme;
    final isExpanded = expandedIds.contains(category.id);
    final left = 8.0 + depth * 14.0;
    return Container(
      margin: EdgeInsets.only(left: left, right: 8, top: 2, bottom: 2),
      decoration: BoxDecoration(
        color: selected ? paperOchre.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          IconButton(
            key: Key('tree_expand_${category.id}'),
            visualDensity: VisualDensity.compact,
            onPressed: hasChildren ? () => onToggleExpand(category) : null,
            icon: Icon(
              isExpanded ? Icons.expand_more : Icons.chevron_right,
              size: 20,
              color: hasChildren ? paperInkSoft : paperLine,
            ),
          ),
          Expanded(
            child: InkWell(
              key: Key('tree_category_tile_${category.id}'),
              onTap: () => onSelectCategory(category),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 10, 10),
                child: Row(
                  children: [
                    GlyphBadge(glyph: category.glyph, color: category.color, size: 28, fontSize: 13),
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
                    if (category.parentId != null)
                      const Icon(Icons.subdirectory_arrow_right, size: 14, color: paperInkSoft),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _domainTile(BuildContext context, LearningDomain domain, int depth) {
    final text = Theme.of(context).textTheme;
    final selected = _isDomainSelected(domain);
    final left = 26.0 + depth * 14.0;
    return InkWell(
      key: Key('tree_domain_tile_${domain.id}'),
      onTap: () => onSelectDomain(domain),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: EdgeInsets.only(left: left, right: 8, bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? paperStone.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            GlyphBadge(glyph: domain.glyph, color: domain.color, size: 24, fontSize: 12),
            const SizedBox(width: 10),
            Expanded(
              child: Text(domain.displayNameFor(band), style: text.bodyMedium, overflow: TextOverflow.ellipsis),
            ),
            Text('${domain.conceptsFor(band).length}', style: text.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _detailPanel(BuildContext context, ScholarCategory active, List<({LearningDomain domain, Concept concept})> rows) {
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
                Text(active.question.isEmpty ? '（子类型）' : active.question, style: text.bodySmall),
              ],
            ),
          ),
          const Divider(height: 1, color: paperLine),
          Expanded(
            child: rows.isEmpty
                ? const Center(
                    child: EmptyState(
                      icon: Icons.category_outlined,
                      title: '这一类还没有知识',
                      message: '可在此分类或其子类型下添加领域与知识。',
                      padding: EdgeInsets.symmetric(horizontal: 24),
                    ),
                  )
                : ListView.builder(
                    key: const PageStorageKey('library_rows'),
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _knowledgeCard(context, row.concept, row.domain),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _knowledgeCard(BuildContext context, Concept concept, LearningDomain domain) {
    final text = Theme.of(context).textTheme;
    final variant = concept.variantFor(band);
    final tier = learner.tierOf(concept.id);
    final locked = tier == null && !graph.unlocked(concept, learner.readyIds, band);
    final group = _groupOf(concept);
    final statusLabel = locked
        ? '先学前一步'
        : switch (group) { 0 => '未开始', 1 => '学习中', _ => '已掌握' };
    final statusColor = locked
        ? paperStone
        : switch (group) { 0 => paperInkSoft, 1 => paperOchre, _ => paperInk };
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
                Text(variant.doing, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.bodySmall),
                if (_creatorOf(concept).isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.auto_stories_outlined, size: 12, color: paperInkSoft),
                      const SizedBox(width: 4),
                      Text('智者：${_creatorOf(concept)}', style: text.bodySmall),
                    ],
                  ),
                ],
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

class _TreeEntry {
  _TreeEntry.category(this.category, this.depth, this.hasChildren) : domain = null;
  _TreeEntry.domain(this.domain, this.depth)
      : category = null,
        hasChildren = false;

  final ScholarCategory? category;
  final LearningDomain? domain;
  final int depth;
  final bool hasChildren;
}
