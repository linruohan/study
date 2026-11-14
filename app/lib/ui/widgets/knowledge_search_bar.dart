import 'package:flutter/material.dart';

import '../../knowledge/age_band.dart';
import '../../knowledge/concept.dart';
import '../../knowledge/taxonomy.dart';
import '../../knowledge/knowledge_catalog.dart';
import '../../knowledge/knowledge_graph.dart';
import '../theme.dart';
import 'glyph_badge.dart';

/// 顶部知识搜索框：边输边在浮层里列出匹配的知识。
///
/// 搜索范围包含知识主题、做法、问答、备注以及各学习程度的知识点。
class KnowledgeSearchBar extends StatefulWidget {
  const KnowledgeSearchBar({
    super.key,
    required this.catalog,
    required this.graph,
    required this.band,
    required this.onOpen,
  });

  /// 知识目录：学习程度清单来自这里，不再依赖全局单例。
  final KnowledgeCatalog catalog;
  final KnowledgeGraph graph;
  final AgeBand band;

  /// 点中一条结果后打开知识详情。
  final void Function(Concept concept, ScholarCategory category) onOpen;

  @override
  State<KnowledgeSearchBar> createState() => _KnowledgeSearchBarState();
}

class _KnowledgeSearchBarState extends State<KnowledgeSearchBar> {
  final SearchController _controller = SearchController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 按关键词在当前年龄档的知识里做包含匹配。
  ///
  /// 分类名也参与匹配，方便直接搜「历史」找到整类知识。
  List<_KnowledgeHit> _search(String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return const [];
    }
    final degrees = widget.catalog.degrees;
    final hits = <_KnowledgeHit>[];
    for (final category in widget.graph.categories) {
      if (!category.concepts.any((concept) => concept.availableIn(widget.band))) {
        continue;
      }
      final categoryText = category.displayNameFor(widget.band).toLowerCase();
      for (final concept in category.conceptsFor(widget.band)) {
        final variant = concept.variantFor(widget.band);
        final haystack = <String>[
          categoryText,
          variant.topic,
          variant.doing,
          variant.praise,
          variant.check,
          variant.answer,
          variant.note ?? '',
          for (final degree in degrees) ...variant.pointsFor(degree),
        ].join('\n').toLowerCase();
        if (haystack.contains(query)) {
          hits.add(_KnowledgeHit(concept: concept, category: category));
        }
      }
    }
    return hits.take(20).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SearchAnchor(
      searchController: _controller,
      isFullScreen: false,
      builder: (context, controller) {
        return SearchBar(
          controller: controller,
          hintText: '搜索知识…',
          leading: const Icon(Icons.search, size: 20),
          onTap: controller.openView,
          onSubmitted: (_) => controller.openView(),
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: const WidgetStatePropertyAll(paperSurface),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12),
          ),
          constraints: const BoxConstraints(maxHeight: 42),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 14, color: paperInk),
          ),
          hintStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 14, color: paperInkSoft),
          ),
        );
      },
      suggestionsBuilder: (context, controller) {
        final hits = _search(controller.text);
        if (controller.text.trim().isEmpty) {
          return const [
            ListTile(
              dense: true,
              leading: Icon(Icons.search, size: 18),
              title: Text('输入关键词，搜索知识主题、做法或知识点'),
            ),
          ];
        }
        if (hits.isEmpty) {
          return [
            ListTile(
              dense: true,
              leading: const Icon(Icons.search_off, size: 18),
              title: Text('没有找到「${controller.text.trim()}」相关的知识'),
            ),
          ];
        }
        return [
          for (final hit in hits)
            ListTile(
              key: Key('search_result_${hit.concept.id}'),
              leading: GlyphBadge(
                glyph: hit.category.glyph,
                color: hit.category.color,
                size: 28,
                fontSize: 12,
              ),
              title: Text(hit.concept.variantFor(widget.band).topic),
              subtitle: Text(
                hit.category.displayNameFor(widget.band),
              ),
              onTap: () {
                controller.closeView(null);
                widget.onOpen(hit.concept, hit.category);
              },
            ),
        ];
      },
    );
  }
}

/// 一条命中的知识及它所属分类。
class _KnowledgeHit {
  const _KnowledgeHit({required this.concept, required this.category});

  final Concept concept;
  final ScholarCategory category;
}
