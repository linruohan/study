import 'package:flutter/material.dart';

import '../knowledge/age_band.dart';
import '../knowledge/concept.dart';
import '../knowledge/domain.dart';
import '../knowledge/knowledge_graph.dart';
import '../knowledge/taxonomy.dart';
import '../learning/learner_state.dart';
import 'library_category_panel.dart';
import 'theme.dart';
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
    required this.onAddSubtype,
    required this.onAddDomain,
    required this.onAddKnowledge,
    required this.onEditCategory,
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

  /// 在某个分类下新建可嵌套的子类型。
  final ValueChanged<ScholarCategory> onAddSubtype;

  /// 在某个分类下新建领域。
  final ValueChanged<ScholarCategory> onAddDomain;

  /// 在某个分类下新建知识。
  final ValueChanged<ScholarCategory> onAddKnowledge;

  /// 修改某个分类的名称与描述。
  final ValueChanged<ScholarCategory> onEditCategory;

  bool _isDomainSelected(LearningDomain domain) => selection == domain.id;

  ScholarCategory _activeCategory(List<ScholarCategory> roots) {
    if (selection != null) {
      final cat = graph.categoryById(selection!);
      if (cat != null) return cat;
      for (final c in graph.categories) {
        final domains = graph.allDomainsInCategory(c);
        if (domains.any((d) => d.id == selection)) return c;
      }
    }
    return roots.isNotEmpty ? roots.first : graph.categories.first;
  }

  List<_TreeEntry> _visibleEntries() {
    final entries = <_TreeEntry>[];
    void walk(ScholarCategory cat, int depth) {
      final children = graph.childrenOf(cat.id);
      // 树里展示全部领域，空领域也要能看到（新建后可以往里加知识）。
      final domains = graph.allDomainsInCategory(cat);
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
    // 兼容：只补真正找不到父级的异常分类；正常子类必须挂在父级下面，
    // 不能因为父级收起就被拍平到根层级。
    final knownIds = {for (final cat in graph.categories) cat.id};
    for (final cat in graph.categories) {
      final parentId = cat.parentId;
      if (parentId != null && !knownIds.contains(parentId)) {
        walk(cat, 0);
      }
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final roots = graph.rootCategories.isNotEmpty ? graph.rootCategories : graph.categories;
    final active = _activeCategory(roots);
    // 分类 id 与领域 id 可能撞车，先按分类解析，避免分类被误当成领域。
    final selectedCategory =
        selection == null ? null : graph.categoryById(selection!);
    final selectedDomain = selectedCategory != null
        ? null
        : (selection == null ? null : graph.domainById(selection!));
    final entries = _visibleEntries();
    final detail = LibraryCategoryPanel(
      graph: graph,
      band: band,
      learner: learner,
      active: active,
      selectedDomain: selectedDomain,
      onSelectCategory: onSelectCategory,
      onOpen: onOpen,
      onAddSubtype: onAddSubtype,
      onAddDomain: onAddDomain,
      onAddKnowledge: onAddKnowledge,
      onEditCategory: onEditCategory,
    );

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
                Expanded(child: detail),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _categoryStrip(context, roots, active),
              const SizedBox(height: 12),
              Expanded(child: detail),
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
    final domainTargets = graph.allDomainsInCategory(activeRoot);
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
                          // 左侧树只显示分类名，完整描述在右侧详情顶部展示。
                          Text(
                            category.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleMedium,
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
