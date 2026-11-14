import 'package:flutter/material.dart';

import '../data/study_repository.dart';
import '../plan_scheme/plan_scheme.dart';
import 'feedback.dart';
import 'theme.dart';

/// 学习方案页：系统内置方案（蒙学、小学一年级……大一等等）+ 本人自建方案。
///
/// 内置方案只读，可一键复制为自己的方案再改；
/// 自建方案支持空白创建、编辑与删除。
class PlanSchemesPage extends StatefulWidget {
  const PlanSchemesPage({super.key, required this.repository});

  final StudyRepository repository;

  @override
  State<PlanSchemesPage> createState() => _PlanSchemesPageState();
}

class _PlanSchemesPageState extends State<PlanSchemesPage> {
  List<PlanScheme> _schemes = const [];
  bool _loading = true;
  bool _stale = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload({bool showSpinner = true}) async {
    setState(() {
      if (showSpinner) {
        _loading = true;
      }
      _error = null;
    });
    try {
      final schemes = await widget.repository.fetchPlanSchemes();
      if (mounted) {
        setState(() {
          _schemes = schemes;
          _stale = widget.repository.planSchemesStale;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _loading = false;
        });
      }
    }
  }

  /// 按阶段分组；内置方案在前（stageSort 升序），自建方案单独一组。
  Map<String, List<PlanScheme>> get _grouped {
    final groups = <String, List<PlanScheme>>{};
    final builtin = [
      for (final scheme in _schemes)
        if (scheme.isBuiltin) scheme,
    ]..sort((a, b) {
        final byStage = a.stageSort.compareTo(b.stageSort);
        return byStage != 0 ? byStage : a.sortOrder.compareTo(b.sortOrder);
      });
    final own = [
      for (final scheme in _schemes)
        if (!scheme.isBuiltin) scheme,
    ];
    for (final scheme in builtin) {
      groups
          .putIfAbsent(scheme.stage, () => [])
          .add(scheme);
    }
    if (own.isNotEmpty) {
      groups['mine'] = own;
    }
    return groups;
  }

  Future<void> _openDetail(PlanScheme scheme) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _PlanSchemeDetailPage(
          repository: widget.repository,
          schemeId: scheme.id,
        ),
      ),
    );
    // 回来后静默刷新，不清空整页转圈；已有数据保持可见。
    if (mounted) {
      _reload(showSpinner: false);
    }
  }

  Future<void> _createBlank() async {
    final created = await Navigator.of(context).push<PlanScheme>(
      MaterialPageRoute(
        builder: (_) => _PlanSchemeFormPage(repository: widget.repository),
      ),
    );
    if (created != null) {
      if (!mounted) return;
      showSuccessToast(context, '方案已创建');
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('学习方案')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createBlank,
        icon: const Icon(Icons.add),
        label: const Text('自建方案'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _reload, child: const Text('重试')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _reload(showSpinner: false),
                  child: _SchemeList(
                    grouped: _grouped,
                    stale: _stale,
                    onOpen: _openDetail,
                  ),
                ),
    );
  }
}

/// 方案列表的懒加载实现：分组展平成行，滚动到哪里构建到哪里。
class _SchemeList extends StatelessWidget {
  const _SchemeList({
    required this.grouped,
    required this.stale,
    required this.onOpen,
  });

  final Map<String, List<PlanScheme>> grouped;
  final bool stale;
  final void Function(PlanScheme scheme) onOpen;

  @override
  Widget build(BuildContext context) {
    final rows = <_SchemeRow>[
      if (stale)
        const _SchemeRow.stale(),
      for (final entry in grouped.entries) ...[
        _SchemeRow.header(entry.key),
        for (final scheme in entry.value) _SchemeRow.scheme(scheme),
      ],
    ];
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row.isStaleBanner) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(Icons.cloud_off, size: 16, color: paperInkSoft),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '当前是离线时的旧数据，联网后会自动更新。',
                    style: TextStyle(color: paperInkSoft),
                  ),
                ),
              ],
            ),
          );
        }
        if (row.stage != null) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              row.stage == 'mine' ? '我的方案' : kPlanSchemeStageLabels[row.stage!] ?? row.stage!,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: paperInkSoft,
                  ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: PaperCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Row(
                children: [
                  Expanded(child: Text(row.scheme!.name)),
                  if (row.scheme!.isBuiltin)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: paperBackground,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: paperLine),
                      ),
                      child: const Text('内置', style: TextStyle(fontSize: 11, color: paperInkSoft)),
                    ),
                ],
              ),
              subtitle: row.scheme!.description.isEmpty
                  ? null
                  : Text(
                      row.scheme!.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
              onTap: () => onOpen(row.scheme!),
            ),
          ),
        );
      },
    );
  }
}

/// 展平后的列表行：离线提示 / 阶段标题 / 方案卡片。
class _SchemeRow {
  const _SchemeRow.header(this.stage)
      : scheme = null,
        isStaleBanner = false;
  const _SchemeRow.scheme(this.scheme)
      : stage = null,
        isStaleBanner = false;
  const _SchemeRow.stale()
      : stage = null,
        scheme = null,
        isStaleBanner = true;

  final String? stage;
  final PlanScheme? scheme;
  final bool isStaleBanner;
}

/// 方案详情：按维度分节展示条目（知识内容 + 学习程度 + 可选关联概念）。
class _PlanSchemeDetailPage extends StatefulWidget {
  const _PlanSchemeDetailPage({
    required this.repository,
    required this.schemeId,
  });

  final StudyRepository repository;
  final String schemeId;

  @override
  State<_PlanSchemeDetailPage> createState() => _PlanSchemeDetailPageState();
}

class _PlanSchemeDetailPageState extends State<_PlanSchemeDetailPage> {
  PlanScheme? _scheme;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final scheme = await widget.repository.fetchPlanScheme(widget.schemeId);
      if (mounted) {
        setState(() {
          _scheme = scheme;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _loading = false;
        });
      }
    }
  }

  /// 复制为我的方案（内置方案的主要用法）。
  Future<void> _clone() async {
    try {
      final clone = await widget.repository.clonePlanScheme(widget.schemeId);
      if (!mounted) return;
      showSuccessToast(context, '已复制为我的方案');
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => _PlanSchemeDetailPage(
            repository: widget.repository,
            schemeId: clone.id,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        await showFailureDialog(context, title: '复制失败', reason: '$error');
      }
    }
  }

  /// 编辑自建方案。
  Future<void> _edit() async {
    final scheme = _scheme;
    if (scheme == null) return;
    final updated = await Navigator.of(context).push<PlanScheme>(
      MaterialPageRoute(
        builder: (_) => _PlanSchemeFormPage(repository: widget.repository, existing: scheme),
      ),
    );
    if (updated != null) {
      if (!mounted) return;
      showSuccessToast(context, '方案已更新');
      _reload();
    }
  }

  Future<void> _delete() async {
    final scheme = _scheme;
    if (scheme == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这个方案？'),
        content: Text('「${scheme.name}」删除后不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('留着'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.deletePlanScheme(scheme.id);
      if (!mounted) return;
      showSuccessToast(context, '方案已删除');
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        await showFailureDialog(context, title: '删除失败', reason: '$error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = _scheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(scheme?.name ?? '方案详情'),
        actions: [
          if (scheme != null && scheme.isBuiltin)
            IconButton(
              tooltip: '复制为我的方案',
              icon: const Icon(Icons.copy_outlined),
              onPressed: _clone,
            ),
          if (scheme != null && !scheme.isBuiltin) ...[
            IconButton(tooltip: '编辑', icon: const Icon(Icons.edit_outlined), onPressed: _edit),
            IconButton(tooltip: '删除', icon: const Icon(Icons.delete_outline), onPressed: _delete),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  // 第 0 行是说明（有才占位），后面按维度逐行懒加载。
                  itemCount:
                      scheme!.dimensions.length + (scheme.description.isEmpty ? 0 : 1),
                  itemBuilder: (context, index) {
                    if (scheme.description.isNotEmpty) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            scheme.description,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: paperInkSoft,
                                ),
                          ),
                        );
                      }
                      return _dimensionCard(context, scheme.dimensions[index - 1]);
                    }
                    return _dimensionCard(context, scheme.dimensions[index]);
                  },
                ),
    );
  }

  Widget _dimensionCard(BuildContext context, PlanSchemeDimension dimension) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PaperCard(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                dimension.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final item in dimension.items)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(item.content),
                      if (item.expectedLevel.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '程度：${item.expectedLevel}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: paperInkSoft,
                                ),
                          ),
                        ),
                      if (item.conceptTopic != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '关联知识：${item.conceptTopic}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: paperOchre,
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 自建/编辑方案表单：名称、阶段、描述与维度条目（动态增删）。
class _PlanSchemeFormPage extends StatefulWidget {
  const _PlanSchemeFormPage({
    required this.repository,
    this.existing,
  });

  final StudyRepository repository;
  final PlanScheme? existing;

  @override
  State<_PlanSchemeFormPage> createState() => _PlanSchemeFormPageState();
}

class _PlanSchemeFormPageState extends State<_PlanSchemeFormPage> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _description =
      TextEditingController(text: widget.existing?.description ?? '');
  late String _stage = widget.existing?.stage ?? kPlanSchemeStageOrder.keys.first;
  late final List<_DimensionDraft> _dimensions = [
    if (widget.existing != null)
      for (final dimension in widget.existing!.dimensions)
        _DimensionDraft(
          name: dimension.name,
          items: [
            for (final item in dimension.items)
              _ItemDraft(content: item.content, expectedLevel: item.expectedLevel),
          ],
        ),
  ];
  bool _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void dispose() {
    // 释放全部控制器：名称、说明 + 每个维度/条目的输入框。
    _name.dispose();
    _description.dispose();
    for (final dimension in _dimensions) {
      dimension.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showFailureToast(context, '先给方案起个名字');
      return;
    }
    final dimensions = [
      for (final dimension in _dimensions)
        if (dimension.nameController.text.trim().isNotEmpty) dimension,
    ];
    final scheme = PlanScheme(
      id: widget.existing?.id ?? '',
      name: name,
      stage: _stage,
      stageSort: widget.existing?.stageSort ?? 9,
      sortOrder: widget.existing?.sortOrder ?? 0,
      description: _description.text.trim(),
      isBuiltin: false,
      ownerUserId: widget.existing?.ownerUserId,
      dimensions: [
        for (final dimension in dimensions)
          PlanSchemeDimension(
            id: '',
            name: dimension.nameController.text.trim(),
            sortOrder: 0,
            items: [
              for (final item in dimension.items)
                if (item.contentController.text.trim().isNotEmpty)
                  PlanSchemeItem(
                    id: '',
                    content: item.contentController.text.trim(),
                    expectedLevel: item.levelController.text.trim(),
                  ),
            ],
          ),
      ],
    );
    setState(() => _saving = true);
    try {
      final saved = _editing
          ? await widget.repository.updatePlanScheme(scheme)
          : await widget.repository.createPlanScheme(scheme);
      if (mounted) {
        Navigator.of(context).pop(saved);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        await showFailureDialog(context, title: '保存失败', reason: '$error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? '编辑方案' : '自建方案'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: '方案名称'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _stage,
            decoration: const InputDecoration(labelText: '阶段'),
            items: [
              for (final entry in kPlanSchemeStageLabels.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _stage = value);
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            decoration: const InputDecoration(labelText: '方案说明（可选）'),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          for (var d = 0; d < _dimensions.length; d++) _dimensionEditor(d),
          OutlinedButton.icon(
            onPressed: () {
              setState(() => _dimensions.add(_DimensionDraft()));
            },
            icon: const Icon(Icons.add),
            label: const Text('加一个维度'),
          ),
        ],
      ),
    );
  }

  Widget _dimensionEditor(int index) {
    final dimension = _dimensions[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PaperCard(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: dimension.nameController,
                      decoration: const InputDecoration(labelText: '维度名称（如「语文」）'),
                    ),
                  ),
                  IconButton(
                    tooltip: '移除维度',
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () {
                      setState(() {
                        final removed = _dimensions.removeAt(index);
                        removed.dispose();
                      });
                    },
                  ),
                ],
              ),
              for (var i = 0; i < dimension.items.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            TextField(
                              controller: dimension.items[i].contentController,
                              decoration: const InputDecoration(labelText: '知识内容'),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: dimension.items[i].levelController,
                              decoration: const InputDecoration(labelText: '学习程度（可选）'),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: '移除条目',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            final removed = dimension.items.removeAt(i);
                            removed.dispose();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() => dimension.items.add(_ItemDraft()));
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('加一条'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DimensionDraft {
  _DimensionDraft({String name = '', List<_ItemDraft> items = const []})
      : nameController = TextEditingController(text: name),
        items = [...items];

  final TextEditingController nameController;
  final List<_ItemDraft> items;

  void dispose() {
    nameController.dispose();
    for (final item in items) {
      item.dispose();
    }
  }
}

class _ItemDraft {
  _ItemDraft({String content = '', String expectedLevel = ''})
      : contentController = TextEditingController(text: content),
        levelController = TextEditingController(text: expectedLevel);

  final TextEditingController contentController;
  final TextEditingController levelController;

  void dispose() {
    contentController.dispose();
    levelController.dispose();
  }
}
