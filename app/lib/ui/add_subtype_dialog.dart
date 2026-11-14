import 'package:flutter/material.dart';

import '../data/study_repository.dart';
import '../knowledge/knowledge_graph.dart';
import '../knowledge/taxonomy.dart';
import 'theme.dart';

/// 可选的子类型色：与领域色保持同一套纸本配色。
const _colorOptions = <_ColorOption>[
  _ColorOption('赭石', '#8C4A2F', paperOchre),
  _ColorOption('石青', '#3E6F8C', paperStone),
  _ColorOption('松绿', '#4F6B4A', Color(0xFF4F6B4A)),
  _ColorOption('黛紫', '#6B5375', Color(0xFF6B5375)),
  _ColorOption('赭黄', '#9A7B3F', Color(0xFF9A7B3F)),
  _ColorOption('墨灰', '#7A6A54', Color(0xFF7A6A54)),
];

/// 一种可选的颜色：显示名、入库的 #RRGGBB 与预览色。
class _ColorOption {
  const _ColorOption(this.label, this.hex, this.color);

  final String label;
  final String hex;
  final Color color;
}

/// 在知识库中新建分类子类型（可继续嵌套）的弹窗。
///
/// 挂在当前选中的分类下，id 由客户端按时间生成，成功后交回新分类 id。
class AddSubtypeDialog extends StatefulWidget {
  const AddSubtypeDialog({
    super.key,
    required this.repository,
    required this.parent,
    required this.graph,
  });

  final StudyRepository repository;

  /// 新子类型默认挂在哪个分类下（当前选中的分类）。
  final ScholarCategory parent;

  /// 分类图谱：用来列出可选父类，嵌套层级用缩进展示。
  final KnowledgeGraph graph;

  @override
  State<AddSubtypeDialog> createState() => _AddSubtypeDialogState();
}

class _AddSubtypeDialogState extends State<AddSubtypeDialog> {
  final _nameController = TextEditingController();
  final _questionController = TextEditingController();
  final _glyphController = TextEditingController(text: '类');

  var _colorHex = _colorOptions.first.hex;
  var _saving = false;
  String? _error;

  /// 父类 id：默认是当前分类，也可以在弹窗里改成其他分类。
  late String _parentId = widget.parent.id;

  /// 可选父类列表：按树的顺序拍平，用 depth 表示嵌套层级。
  List<({ScholarCategory category, int depth})> _parentOptions() {
    final options = <({ScholarCategory category, int depth})>[];
    final visited = <String>{};

    void walk(ScholarCategory category, int depth) {
      if (!visited.add(category.id)) {
        return;
      }
      options.add((category: category, depth: depth));
      for (final child in widget.graph.childrenOf(category.id)) {
        walk(child, depth + 1);
      }
    }

    for (final root in widget.graph.rootCategories) {
      walk(root, 0);
    }
    // 父级缺失的异常分类也要能选到，避免它们从下拉里消失。
    for (final category in widget.graph.categories) {
      if (!visited.contains(category.id)) {
        walk(category, 0);
      }
    }
    return options;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _questionController.dispose();
    _glyphController.dispose();
    super.dispose();
  }

  /// 提交子类型：名称必填，说明与符号可空，成功后关闭弹窗并交回 id。
  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '请填写子类型名称');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final created = await widget.repository.createCategory(
        id: 'cat_${DateTime.now().microsecondsSinceEpoch}',
        parentId: _parentId,
        name: name,
        question: _questionController.text.trim(),
        glyph: _glyphController.text.trim().isEmpty
            ? '类'
            : _glyphController.text.trim(),
        color: _colorHex,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(created['id'] as String?);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = '创建失败：$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      key: const Key('add_subtype_dialog'),
      title: const Text('添加子类型'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                key: const Key('add_subtype_parent'),
                initialValue: _parentId,
                decoration: const InputDecoration(
                  labelText: '父类',
                  helperText: '子类型会挂在选中的父类下面',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final option in _parentOptions())
                    DropdownMenuItem(
                      value: option.category.id,
                      // 全角空格缩进，让嵌套层级一眼能看出来。
                      child: Text(
                        '${'　' * option.depth}${option.category.name}',
                      ),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _parentId = value);
                        }
                      },
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('add_subtype_name'),
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '子类型名称',
                  hintText: '例如：蒙学、算学、礼制',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _questionController,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: '说明（可选）',
                  hintText: '这个子类型收什么内容，方便区分',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              TextField(
                controller: _glyphController,
                maxLength: 2,
                decoration: const InputDecoration(
                  labelText: '符号',
                  hintText: '没有大图时显示，例如「蒙」',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 4),
              Text('子类型色', style: text.bodySmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final option in _colorOptions) _colorDot(option),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: text.bodySmall?.copyWith(color: paperOchre),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('add_subtype_submit'),
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('创建'),
        ),
      ],
    );
  }

  /// 一个颜色选择圆点；选中时描一圈墨色外框并打勾。
  Widget _colorDot(_ColorOption option) {
    final selected = option.hex == _colorHex;
    return Tooltip(
      message: option.label,
      child: InkWell(
        key: Key('add_subtype_color_${option.hex}'),
        borderRadius: BorderRadius.circular(999),
        onTap: () => setState(() => _colorHex = option.hex),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: option.color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? paperInk : paperLine,
              width: selected ? 2 : 1,
            ),
          ),
          child: selected
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}
