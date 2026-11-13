import 'package:flutter/material.dart';

import '../data/sage_api.dart';
import '../data/sage_service.dart';
import '../data/study_repository.dart';
import '../knowledge/age_band.dart';
import '../knowledge/concept.dart';
import '../knowledge/domain.dart';
import '../knowledge/knowledge_catalog.dart';
import '../knowledge/study_degree.dart';
import '../knowledge/taxonomy.dart';
import '../profile/profile_store.dart';
import 'theme.dart';
import 'widgets/page_header.dart';

/// 智者页：填名字、提交知识或知识点、创建可嵌套子类型、查看贡献。
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

  String _kind = 'knowledge';
  final _nameController = TextEditingController();
  final _topicController = TextEditingController();
  final _doingController = TextEditingController();
  final _noteController = TextEditingController();

  final _catIdController = TextEditingController();
  final _catNameController = TextEditingController();
  final _catQuestionController = TextEditingController();
  ScholarCategory? _parentCategory;

  AgeBand? _band;
  StudyDegree? _degree;
  LearningDomain? _domain;
  Concept? _concept;

  var _nameLoaded = false;
  var _savingName = false;
  var _submitting = false;
  var _creatingCategory = false;
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
    _topicController.dispose();
    _doingController.dispose();
    _noteController.dispose();
    _catIdController.dispose();
    _catNameController.dispose();
    _catQuestionController.dispose();
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

  Future<void> _submit() async {
    final band = _band;
    final domain = _domain;
    final degree = _degree;
    final concept = _concept;
    final topic = _topicController.text.trim();
    if (band == null || domain == null || degree == null || topic.isEmpty) {
      return _show('请把各项都填完整', true);
    }
    if (_kind == 'point' && concept == null) {
      return _show('请选择要补充到哪条知识', true);
    }
    setState(() => _submitting = true);
    try {
      await _sage.createContribution(
        kind: _kind,
        domainId: domain.id,
        ageBandId: band.id,
        degreeId: degree.id,
        conceptId: _kind == 'point' ? concept?.id : null,
        position: null,
        topic: topic,
        doing: _doingController.text.trim().isEmpty ? null : _doingController.text.trim(),
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      _topicController.clear();
      _doingController.clear();
      _noteController.clear();
      _show('提交成功，已写进知识库', false);
      await _reloadContributions();
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _show('提交失败：$error', true);
    }
  }

  Future<void> _createCategory() async {
    final id = _catIdController.text.trim();
    final name = _catNameController.text.trim();
    if (id.isEmpty || name.isEmpty) {
      return _show('请填写子类型 id 和名称', true);
    }
    setState(() => _creatingCategory = true);
    try {
      await widget.repository.createCategory(
        id: id,
        parentId: _parentCategory?.id,
        name: name,
        question: _catQuestionController.text.trim(),
      );
      KnowledgeCatalog? refreshed;
      try {
        refreshed = await widget.repository.reloadKnowledge();
      } catch (_) {
        refreshed = null;
      }
      if (!mounted) return;
      _catIdController.clear();
      _catNameController.clear();
      _catQuestionController.clear();
      setState(() {
        _creatingCategory = false;
        _parentCategory = null;
      });
      _show(
        refreshed == null ? '子类型已创建，知识库刷新失败，请稍后重试或重启应用。' : '子类型已创建并已刷新知识库，可在知识库中查看。',
        refreshed == null,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _creatingCategory = false);
      _show('创建子类型失败：$e', true);
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
    final catalog = KnowledgeCatalog.instance;
    final bands = catalog.ageBands;
    final degrees = catalog.degrees;
    final domains = catalog.domains;
    final categories = catalog.categories;

    return Scaffold(
      appBar: AppBar(title: const Text('智者 · 添加知识')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            const PageHeader(
              title: '智者 · 添加知识',
              subtitle: '提交知识或知识点、创建可嵌套子类型；审批通过的贡献会进入知识库。',
            ),
            const SizedBox(height: 16),
            _nameCard(text),
            const SizedBox(height: 16),
            _contributionCardForm(text, bands, degrees, domains),
            const SizedBox(height: 16),
            _categoryCreateCard(text, categories),
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

  Widget _contributionCardForm(TextTheme text, List<AgeBand> bands, List<StudyDegree> degrees, List<LearningDomain> domains) {
    return PaperCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('提交知识 / 知识点', style: text.titleMedium),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'knowledge', label: Text('新知识')),
              ButtonSegment(value: 'point', label: Text('补充知识点')),
            ],
            selected: {_kind},
            onSelectionChanged: (v) => setState(() => _kind = v.first),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<AgeBand>(
            initialValue: _band,
            decoration: const InputDecoration(labelText: '年龄档', border: OutlineInputBorder()),
            items: [for (final b in bands) DropdownMenuItem(value: b, child: Text(b.label))],
            onChanged: (v) => setState(() => _band = v),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<StudyDegree>(
            initialValue: _degree,
            decoration: const InputDecoration(labelText: '学习程度', border: OutlineInputBorder()),
            items: [for (final d in degrees) DropdownMenuItem(value: d, child: Text(d.label))],
            onChanged: (v) => setState(() => _degree = v),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<LearningDomain>(
            initialValue: _domain,
            decoration: const InputDecoration(labelText: '领域', border: OutlineInputBorder()),
            items: [
              for (final domain in domains)
                DropdownMenuItem(
                  value: domain,
                  child: Text(domain.displayNameFor(_band ?? bands.first)),
                ),
            ],
            onChanged: (v) => setState(() { _domain = v; _concept = null; }),
          ),
          if (_kind == 'point') ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<Concept>(
              initialValue: _concept,
              decoration: const InputDecoration(labelText: '所属知识（概念）', border: OutlineInputBorder()),
              items: [
                for (final c in (_domain?.concepts.where((c) => _band == null || c.availableIn(_band!)).toList() ?? const <Concept>[]))
                  DropdownMenuItem(value: c, child: Text(_band == null ? c.id : c.variantFor(_band!).topic)),
              ],
              onChanged: (v) => setState(() => _concept = v),
            ),
          ],
          const SizedBox(height: 10),
          TextField(controller: _topicController, decoration: const InputDecoration(labelText: '主题/知识点内容', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _doingController, decoration: const InputDecoration(labelText: '做什么（可选）', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _noteController, maxLines: 2, decoration: const InputDecoration(labelText: '备注（可选）', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('提交'),
          ),
        ],
      ),
    );
  }

  Widget _categoryCreateCard(TextTheme text, List<ScholarCategory> categories) {
    return PaperCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('创建分类子类型（可嵌套）', style: text.titleMedium),
          const SizedBox(height: 8),
          Text('可在九大基类或已有子类型下创建子类型。创建后需重新加载知识库。', style: text.bodySmall),
          const SizedBox(height: 10),
          DropdownButtonFormField<ScholarCategory?>(
            initialValue: _parentCategory,
            decoration: const InputDecoration(labelText: '父分类（可选，空表示基类）', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem<ScholarCategory?>(value: null, child: Text('（作为基类/根分类）')),
              for (final c in categories)
                DropdownMenuItem<ScholarCategory?>(value: c, child: Text('${c.name}${c.parentId == null ? '' : '（子类型）'}')),
            ],
            onChanged: (v) => setState(() => _parentCategory = v),
          ),
          const SizedBox(height: 10),
          TextField(controller: _catIdController, decoration: const InputDecoration(labelText: '子类型 id（唯一）', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _catNameController, decoration: const InputDecoration(labelText: '名称', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _catQuestionController, decoration: const InputDecoration(labelText: '回答的问题/说明（可选）', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: _creatingCategory ? null : _createCategory,
            child: _creatingCategory ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('创建子类型'),
          ),
        ],
      ),
    );
  }
}
