import 'package:flutter/material.dart';

import '../data/study_repository.dart';
import '../knowledge/taxonomy.dart';
import 'theme.dart';

/// 可选的领域色：低饱和，和纸本主题保持一致。
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

/// 在知识库中新建学习领域的弹窗。
///
/// 只负责收集名称、符号和颜色并调用服务端；成功后把新领域 id 交回页面。
class AddDomainDialog extends StatefulWidget {
  const AddDomainDialog({
    super.key,
    required this.repository,
    required this.category,
  });

  final StudyRepository repository;

  /// 新领域挂在哪个分类下。
  final ScholarCategory category;

  @override
  State<AddDomainDialog> createState() => _AddDomainDialogState();
}

class _AddDomainDialogState extends State<AddDomainDialog> {
  final _nameController = TextEditingController();
  final _glyphController = TextEditingController(text: '域');

  var _colorHex = _colorOptions.first.hex;
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _glyphController.dispose();
    super.dispose();
  }

  /// 提交新领域：校验名称后调用接口，成功则关闭弹窗交回领域 id。
  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '请填写领域名称');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final created = await widget.repository.createDomain(
        categoryId: widget.category.id,
        name: name,
        glyph: _glyphController.text.trim().isEmpty
            ? '域'
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
      key: const Key('add_domain_dialog'),
      title: const Text('添加领域'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('所属分类：${widget.category.name}', style: text.bodySmall),
              const SizedBox(height: 12),
              TextField(
                key: const Key('add_domain_name'),
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '领域名称',
                  hintText: '例如：生活与安全',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _glyphController,
                maxLength: 2,
                decoration: const InputDecoration(
                  labelText: '符号',
                  hintText: '没有大图时显示，例如「安」',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 4),
              Text('领域色', style: text.bodySmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final option in _colorOptions)
                    _colorDot(option),
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
          key: const Key('add_domain_submit'),
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
        key: Key('add_domain_color_${option.hex}'),
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
