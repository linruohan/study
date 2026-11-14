import 'package:flutter/material.dart';

import '../data/study_repository.dart';
import '../knowledge/age_band.dart';
import '../knowledge/taxonomy.dart';
import 'theme.dart';

/// 在知识库中新建一条知识的弹窗。
///
/// 知识挂到某个分类下，随后可在详情页按学习程度补充知识点与章节。
class AddKnowledgeDialog extends StatefulWidget {
  const AddKnowledgeDialog({
    super.key,
    required this.repository,
    required this.band,
    required this.categories,
    this.initialCategory,
  });

  final StudyRepository repository;

  /// 当前年龄档，新知识只写这一档的呈现。
  final AgeBand band;

  /// 可选的分类，来自当前知识库的分类树。
  final List<ScholarCategory> categories;

  /// 默认选中的分类，一般是当前选中的分类。
  final ScholarCategory? initialCategory;

  @override
  State<AddKnowledgeDialog> createState() => _AddKnowledgeDialogState();
}

class _AddKnowledgeDialogState extends State<AddKnowledgeDialog> {
  final _topicController = TextEditingController();
  final _doingController = TextEditingController();
  final _noteController = TextEditingController();

  late ScholarCategory _category =
      widget.initialCategory ?? widget.categories.first;

  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _topicController.dispose();
    _doingController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// 提交一条新知识：主题必填，做什么和备注可选。
  Future<void> _submit() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      setState(() => _error = '请填写知识主题');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.createKnowledge(
        categoryId: _category.id,
        ageBandId: widget.band.id,
        topic: topic,
        doing: _doingController.text.trim().isEmpty
            ? null
            : _doingController.text.trim(),
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
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
        _error = '提交失败：$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      key: const Key('add_knowledge_dialog'),
      title: const Text('添加知识'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('年龄档：${widget.band.label}', style: text.bodySmall),
              const SizedBox(height: 12),
              DropdownButtonFormField<ScholarCategory>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: '所属分类',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final category in widget.categories)
                    DropdownMenuItem(
                      value: category,
                      child: Text(category.displayNameFor(widget.band)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _category = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('add_knowledge_topic'),
                controller: _topicController,
                autofocus: true,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: '知识主题',
                  hintText: '例如：看见火要远离',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _doingController,
                maxLength: 500,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '做什么（可选）',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              TextField(
                controller: _noteController,
                maxLength: 2000,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '备注（可选）',
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
              ] else ...[
                const SizedBox(height: 4),
                Text(
                  '创建后可在知识详情页按学习程度补充知识点与章节。',
                  style: text.bodySmall,
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
          key: const Key('add_knowledge_submit'),
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('提交'),
        ),
      ],
    );
  }
}
