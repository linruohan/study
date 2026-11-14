import 'package:flutter/material.dart';

import '../data/study_repository.dart';
import '../knowledge/taxonomy.dart';
import 'theme.dart';

/// 修改分类信息的弹窗：只改名称与描述，提交成功后交回 true。
class EditCategoryDialog extends StatefulWidget {
  const EditCategoryDialog({
    super.key,
    required this.repository,
    required this.category,
    this.parentName,
  });

  final StudyRepository repository;

  /// 要修改的分类。
  final ScholarCategory category;

  /// 父类名称；为 null 表示这是顶级分类。
  final String? parentName;

  @override
  State<EditCategoryDialog> createState() => _EditCategoryDialogState();
}

class _EditCategoryDialogState extends State<EditCategoryDialog> {
  late final _nameController = TextEditingController(text: widget.category.name);
  late final _questionController =
      TextEditingController(text: widget.category.question);

  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _questionController.dispose();
    super.dispose();
  }

  /// 提交修改：名称必填，成功后关闭弹窗。
  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '请填写分类名称');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.updateCategory(
        id: widget.category.id,
        name: name,
        question: _questionController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = '保存失败：$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      key: const Key('edit_category_dialog'),
      title: const Text('修改分类信息'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: '父类',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                // 父类只读展示，避免改名称时误动层级。
                child: Text(
                  widget.parentName ?? '无（顶级分类）',
                  key: const Key('edit_category_parent'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('edit_category_name'),
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '分类名称',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('edit_category_question'),
                controller: _questionController,
                maxLength: 200,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '描述（可选）',
                  hintText: '这一类收什么内容，方便区分',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
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
          key: const Key('edit_category_submit'),
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存'),
        ),
      ],
    );
  }
}
