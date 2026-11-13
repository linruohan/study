import 'package:flutter/material.dart';

import '../data/sage_api.dart';
import '../data/sage_service.dart';
import '../data/study_repository.dart';
import '../profile/profile_store.dart';
import 'theme.dart';
import 'widgets/page_header.dart';

/// 智者页：填写智者名、审核待处理纠错、查看自己的贡献。
///
/// 知识、子类型的添加统一收在「知识库」页面，这里只负责署名与贡献记录。
class SagePage extends StatefulWidget {
  const SagePage({
    super.key,
    required this.repository,
    required this.store,
  });

  final StudyRepository repository;
  final ProfileStore store;

  @override
  State<SagePage> createState() => _SagePageState();
}

class _SagePageState extends State<SagePage> {
  late final SageService _sage = widget.repository.sage;

  final _nameController = TextEditingController();

  var _nameLoaded = false;
  var _savingName = false;
  var _loadingPending = false;
  String? _message;
  bool _messageIsError = false;
  List<SageContribution> _contributions = const [];
  List<Map<String, dynamic>> _pendingCorrections = const [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final name = await _sage.name();
    if (!mounted) return;
    setState(() {
      _nameController.text = name;
      _nameLoaded = true;
    });
    await _reloadContributions();
  }

  Future<void> _reloadContributions() async {
    final list = await _sage.contributions();
    if (!mounted) return;
    setState(() {
      _contributions = list;
    });
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return _show('名字不能为空', true);
    setState(() => _savingName = true);
    try {
      await _sage.saveName(name);
      if (!mounted) return;
      setState(() => _savingName = false);
      _show('名字已保存', false);
      await _reloadContributions();
    } catch (error) {
      if (!mounted) return;
      setState(() => _savingName = false);
      _show('保存名字失败：$error', true);
    }
  }

  Future<void> _loadPendingCorrections() async {
    setState(() => _loadingPending = true);
    try {
      final list = await widget.repository.fetchPendingPointCorrections(limit: 50);
      if (!mounted) return;
      setState(() { _pendingCorrections = list; _loadingPending = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingPending = false);
      _show('加载待审核纠错失败：$e', true);
    }
  }

  Future<void> _reviewPending(Map<String, dynamic> item, bool approve) async {
    final id = item['id'] as String?;
    if (id == null) return;
    try {
      await widget.repository.reviewPointCorrection(correctionId: id, approve: approve, points: approve ? 5 : 0);
      await _loadPendingCorrections();
      if (!mounted) return;
      _show(approve ? '已通过并发放积分' : '已驳回', false);
    } catch (e) {
      if (!mounted) return;
      _show('审核失败：$e', true);
    }
  }

  void _show(String text, bool isError) {
    setState(() {
      _message = text;
      _messageIsError = isError;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('智者 · 我的贡献')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            const PageHeader(
              title: '智者 · 我的贡献',
              subtitle: '留一个署名，审核别人的纠错，回顾自己写进知识库的内容。知识与子类型请在知识库页面添加。',
            ),
            const SizedBox(height: 16),
            _nameCard(text),
            if (_message != null) ...[
              const SizedBox(height: 12),
              PaperCard(
                color: _messageIsError ? Colors.red.withValues(alpha: 0.08) : paperOchre.withValues(alpha: 0.08),
                child: Text(_message!, style: text.bodyMedium),
              ),
            ],
            const SizedBox(height: 16),
            PaperCard(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('待审核纠错', style: text.titleMedium)),
                  FilledButton.tonal(
                    onPressed: _loadingPending ? null : _loadPendingCorrections,
                    child: _loadingPending ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('刷新'),
                  ),
                ]),
                const SizedBox(height: 8),
                if (_pendingCorrections.isEmpty)
                  Text('暂无待审核纠错，或点击刷新加载。', style: text.bodySmall)
                else
                  for (final item in _pendingCorrections.take(10))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(border: Border.all(color: paperLine), borderRadius: BorderRadius.circular(10)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('知识点 ${item['conceptId']} · ${item['ageBandId']} · ${item['degreeId']} · #${item['position']}', style: text.bodySmall),
                          const SizedBox(height: 4),
                          Text(item['body'] as String? ?? '', style: text.bodyMedium),
                          if ((item['suggestedText'] as String?)?.isNotEmpty == true)
                            Text('建议：${item['suggestedText']}', style: text.bodySmall),
                          const SizedBox(height: 6),
                          Wrap(spacing: 8, children: [
                            OutlinedButton(onPressed: () => _reviewPending(item, false), child: const Text('驳回')),
                            FilledButton(onPressed: () => _reviewPending(item, true), child: const Text('通过(+5分)')),
                          ]),
                        ]),
                      ),
                    ),
              ]),
            ),
            const SizedBox(height: 20),
            Text('我的贡献', style: text.titleMedium),
            const SizedBox(height: 8),
            if (_contributions.isEmpty)
              Text('还没有贡献记录。', style: text.bodySmall)
            else
              for (final c in _contributions.take(20))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PaperCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${c.kind == 'knowledge' ? '知识' : '知识点'} · ${c.status}', style: text.labelMedium),
                        const SizedBox(height: 4),
                        Text(c.topic, style: text.bodyMedium),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _nameCard(TextTheme text) {
    return PaperCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('智者名', style: text.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  enabled: _nameLoaded,
                  decoration: const InputDecoration(hintText: '输入你的名字', border: OutlineInputBorder(), isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _savingName ? null : _saveName,
                child: _savingName ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('保存'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
