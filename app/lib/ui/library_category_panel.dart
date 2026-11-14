import 'package:flutter/material.dart';

import '../knowledge/age_band.dart';
import '../knowledge/concept.dart';
import '../knowledge/knowledge_catalog.dart';
import '../knowledge/knowledge_graph.dart';
import '../knowledge/taxonomy.dart';
import '../learning/learner_state.dart';
import 'theme.dart';

/// 知识库右侧主视图：面包屑、分类信息、子类与知识两组自适应卡片。
///
/// 分类树上父类/子类均可嵌套，知识直接挂在分类下：选中一个分类时，
/// 「子类」列出它的直接子类，「知识」列出它直属的知识。
class LibraryCategoryPanel extends StatelessWidget {
  const LibraryCategoryPanel({
    super.key,
    required this.graph,
    required this.band,
    required this.learner,
    required this.active,
    required this.onSelectCategory,
    required this.onOpen,
    required this.onAddSubtype,
    required this.onAddKnowledge,
    required this.onEditCategory,
  });

  final KnowledgeGraph graph;
  final AgeBand band;
  final LearnerState learner;

  /// 当前选中的分类。
  final ScholarCategory active;

  final ValueChanged<ScholarCategory> onSelectCategory;
  final void Function(Concept concept, ScholarCategory category) onOpen;
  final ValueChanged<ScholarCategory> onAddSubtype;
  final ValueChanged<ScholarCategory> onAddKnowledge;

  /// 修改当前分类的名称与描述。
  final ValueChanged<ScholarCategory> onEditCategory;

  /// 分类链路：从根分类到当前分类。
  List<ScholarCategory> _lineage() {
    final list = <ScholarCategory>[];
    ScholarCategory? current = active;
    while (current != null) {
      list.insert(0, current);
      final parentId = current.parentId;
      if (parentId == null) {
        break;
      }
      current = graph.categoryById(parentId);
    }
    return list;
  }

  /// 当前分类的直接子类。
  List<ScholarCategory> get _children => graph.childrenOf(active.id);

  /// 当前分类直属的知识。
  List<Concept> get _knowledge => active.conceptsFor(band);

  /// 子类及其后代下的知识总数。
  int _knowledgeCountUnder(ScholarCategory category) {
    return graph
        .categoriesUnder(category)
        .fold(0, (sum, category) => sum + category.conceptsFor(band).length);
  }

  int _groupOf(Concept concept) {
    final tier = learner.tierOf(concept.id);
    if (tier == null) {
      return 0;
    }
    return tier.unlocksNext ? 2 : 1;
  }

  String _creatorOf(Concept concept) {
    final catalog = KnowledgeCatalog.maybeInstance;
    if (catalog == null) {
      return '';
    }
    return catalog.sageCredits.creatorOfConcept(concept.id);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final lineage = _lineage();
    // 一级分类没有归属可展示，面包屑只放在标题最右侧。
    final showBreadcrumb = lineage.length > 1;
    final title = active.displayNameFor(band);
    final description =
        active.question.isEmpty ? '暂无描述' : active.question;
    final descriptionStyle = active.question.isEmpty
        ? text.bodySmall?.copyWith(color: paperInkSoft)
        : text.bodySmall;

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
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) => Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: Text(title, style: text.headlineSmall)),
                      if (showBreadcrumb) ...[
                        const SizedBox(width: 12),
                        ConstrainedBox(
                          // 面包屑最多占一半宽度，给标题留出空间。
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth * 0.5,
                          ),
                          child: _breadcrumb(context, lineage),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(description, style: descriptionStyle),
                    ),
                    const SizedBox(width: 8),
                    _actions(context),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: paperLine),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = _columnsFor(constraints.maxWidth - 36);
                return SingleChildScrollView(
                  key: PageStorageKey('library_detail_${active.id}'),
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SectionGrid(
                        key: const ValueKey('section_children'),
                        title: '子类',
                        count: _children.length,
                        columns: columns,
                        tiles: [
                          for (final category in _children)
                            _childTile(context, category),
                        ],
                        emptyHint: _emptyHint(text, '这个分类下还没有子类。'),
                        addKey: const Key('section_add_subtype'),
                        addTooltip: '添加子类',
                        onAdd: () => onAddSubtype(active),
                        sortKey: const Key('section_sort_subtype'),
                      ),
                      const SizedBox(height: 22),
                      _SectionGrid(
                        key: const ValueKey('section_knowledge'),
                        title: '知识',
                        count: _knowledge.length,
                        columns: columns,
                        tiles: [
                          for (final concept in _knowledge)
                            _knowledgeTile(context, concept),
                        ],
                        emptyHint: _emptyHint(
                          text,
                          '这个分类还没有直属知识，可在此分类或子类下添加。',
                        ),
                        addKey: const Key('section_add_knowledge'),
                        addTooltip: '添加知识',
                        onAdd: () => onAddKnowledge(active),
                        sortKey: const Key('section_sort_knowledge'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 面包屑：祖先分类都可点击，最后一段显示当前分类。
  Widget _breadcrumb(BuildContext context, List<ScholarCategory> lineage) {
    final text = Theme.of(context).textTheme;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 2,
      runSpacing: 2,
      children: [
        for (var i = 0; i < lineage.length; i++) ...[
          if (i > 0)
            const Icon(Icons.chevron_right, size: 14, color: paperInkSoft),
          InkWell(
            key: Key('breadcrumb_${lineage[i].id}'),
            borderRadius: BorderRadius.circular(6),
            onTap: () => onSelectCategory(lineage[i]),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                lineage[i].name,
                style: i == lineage.length - 1
                    ? text.bodySmall?.copyWith(color: paperInk)
                    : text.bodySmall,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 添加子类型 / 知识，以及修改分类信息；只用图标，悬停给提示。
  Widget _actions(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _compactIconButton(
          key: const Key('library_add_subtype'),
          icon: Icons.account_tree_outlined,
          tooltip: '添加子类',
          onPressed: () => onAddSubtype(active),
        ),
        _compactIconButton(
          key: const Key('library_add_knowledge'),
          icon: Icons.menu_book_outlined,
          tooltip: '添加知识',
          onPressed: () => onAddKnowledge(active),
        ),
        _compactIconButton(
          key: const Key('library_edit_category'),
          icon: Icons.edit_outlined,
          tooltip: '修改分类信息',
          onPressed: () => onEditCategory(active),
        ),
      ],
    );
  }

  Widget _emptyHint(TextTheme text, String message) {
    return Text(message, style: text.bodySmall);
  }

  /// 按可用宽度算每行卡片数；卡片最小约 86 宽，最多 8 列。
  int _columnsFor(double width) {
    const minTileWidth = 86.0;
    const spacing = 12.0;
    if (width <= 0) {
      return 2;
    }
    final count = ((width + spacing) / (minTileWidth + spacing)).floor();
    return count.clamp(2, 8);
  }

  /// 一个子类卡片：彩色圆角图标 + 名称 + 知识数量。
  Widget _childTile(BuildContext context, ScholarCategory category) {
    return _AppTile(
      key: Key('category_card_${category.id}'),
      glyph: category.glyph,
      color: category.color,
      label: category.displayNameFor(band),
      caption: '${_knowledgeCountUnder(category)} 条知识',
      onTap: () => onSelectCategory(category),
    );
  }

  /// 一条知识卡片：图标沿用知识符号，副标题给学习状态。
  Widget _knowledgeTile(BuildContext context, Concept concept) {
    final variant = concept.variantFor(band);
    final tier = learner.tierOf(concept.id);
    final locked = tier == null && !graph.unlocked(concept, learner.readyIds, band);
    final group = _groupOf(concept);
    final statusLabel = locked
        ? '先学前一步'
        : switch (group) { 0 => '未开始', 1 => '学习中', _ => '已掌握' };
    final creator = _creatorOf(concept);
    return _AppTile(
      key: Key('knowledge_${concept.id}'),
      glyph: variant.glyph ?? active.glyph,
      color: active.color,
      label: variant.topic,
      caption: creator.isEmpty ? statusLabel : '$statusLabel · 智者 $creator',
      locked: locked,
      onTap: () => onOpen(concept, active),
    );
  }
}

/// 分组区块：标题 + 数量 + 添加 / 排序按钮，下面是可换行的卡片网格。
///
/// 顺序状态放在区块内部，切换只影响当前这一组。
class _SectionGrid extends StatefulWidget {
  const _SectionGrid({
    super.key,
    required this.title,
    required this.count,
    required this.columns,
    required this.tiles,
    required this.emptyHint,
    required this.addKey,
    required this.addTooltip,
    required this.onAdd,
    required this.sortKey,
  });

  final String title;
  final int count;
  final int columns;
  final List<Widget> tiles;
  final Widget emptyHint;
  final Key addKey;
  final String addTooltip;
  final VoidCallback onAdd;
  final Key sortKey;

  @override
  State<_SectionGrid> createState() => _SectionGridState();
}

class _SectionGridState extends State<_SectionGrid> {
  /// true 表示倒序展示。
  var _descending = false;

  /// 切换顺序 / 倒序。
  void _toggleSort() {
    setState(() => _descending = !_descending);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tiles = _descending ? widget.tiles.reversed.toList() : widget.tiles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: paperOchre.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(widget.title, style: text.titleMedium),
            const SizedBox(width: 8),
            Text('${widget.count}', style: text.bodySmall),
            const Spacer(),
            _compactIconButton(
              key: widget.addKey,
              icon: Icons.add,
              tooltip: widget.addTooltip,
              onPressed: widget.onAdd,
            ),
            _compactIconButton(
              key: widget.sortKey,
              icon: _descending ? Icons.arrow_downward : Icons.arrow_upward,
              tooltip: _descending ? '倒序，点击切换顺序' : '顺序，点击切换倒序',
              onPressed: _toggleSort,
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (tiles.isEmpty)
          widget.emptyHint
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: tiles.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: widget.columns,
              mainAxisExtent: 124,
              crossAxisSpacing: 8,
              mainAxisSpacing: 6,
            ),
            itemBuilder: (context, index) => tiles[index],
          ),
      ],
    );
  }
}

/// 紧凑的图标按钮，说明放进 Tooltip。
Widget _compactIconButton({
  required Key key,
  required IconData icon,
  required String tooltip,
  required VoidCallback onPressed,
}) {
  return IconButton(
    key: key,
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon, size: 20),
    color: paperInkSoft,
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
  );
}

/// 图标式卡片：圆角色块 + 下方标签，点开进入下一层。
class _AppTile extends StatelessWidget {
  const _AppTile({
    super.key,
    required this.glyph,
    required this.color,
    required this.label,
    required this.caption,
    required this.onTap,
    this.locked = false,
  });

  final String glyph;
  final Color color;
  final String label;
  final String caption;
  final VoidCallback onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: locked ? color.withValues(alpha: 0.45) : color,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.18),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      glyph,
                      style: const TextStyle(
                        fontSize: 25,
                        height: 1.1,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                if (locked)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 17,
                      height: 17,
                      decoration: const BoxDecoration(
                        color: paperSurface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_outline, size: 11, color: paperStone),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(fontSize: 13, height: 1.25),
            ),
            const SizedBox(height: 1),
            Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(fontSize: 11, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}
