import 'package:flutter/material.dart';

import '../data/sage_api.dart';
import '../data/sage_service.dart';
import '../data/study_repository.dart';
import '../knowledge/age_band.dart';
import '../knowledge/concept.dart';
import '../knowledge/domain.dart';
import '../knowledge/knowledge_catalog.dart';
import '../knowledge/study_degree.dart';
import '../profile/profile_store.dart';
import 'theme.dart';
import 'widgets/page_header.dart';

/// 智者页：填名字、提交知识或知识点、看自己的贡献。
///
/// 提交即审批：通过后知识或知识点写进知识库，查询时会显示创建者名。
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

  /// 当前选中的提交类型：knowledge 新建知识，point 补充知识点。
  String _kind = 'knowledge';

  final _nameController = TextEditingController();
  final _topicController = TextEditingController();
  final _doingController = TextEditingController();
  final _noteController = TextEditingController();

  AgeBand? _band;
  StudyDegree? _degree;
  LearningDomain? _domain;
  Concept? _concept;

  var _nameLoaded = false;
  var _savingName = false;
  var _submitting = false;
  String? _message;
  bool _messageIsError = false;
  List<SageContribution> _contributions = const [];

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
    super.dispose();
  }

  Future<void> _init() async {
    final name = await _sage.name();
    if (!mounted) {
      return;
    }
    setState(() {
      _nameController.text = name;
      _nameLoaded = true;
    });
    await _reloadContributions();
  }

  Future<void> _reloadContributions() async {
    final list = await _sage.contributions();
    if (!mounted) {
      return;
    }
    setState(() {
      _contributions = list;
    });
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return _show('名字不能为空', true);
    }
    setState(() => _savingName = true);
    try {
      await _sage.saveName(name);
      if (!mounted) {
        return;
      }
      setState(() => _savingName = false);
      _show('名字已保存', false);
      await _reloadContributions();
    } catch (error) {
      if (!mounted) {
        return;
      }
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
    if (_kind == 'point' && (concept == null)) {
      return _show('请选择要补充到哪条知识上', true);
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
      if (!mounted) {
        return;
      }
      setState(() => _submitting = false);
      _topicController.clear();
      _doingController.clear();
      _noteController.clear();
      _show('提交成功，已写进知识库', false);
      await _reloadContributions();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _submitting = false);
      _show('提交失败：$error', true);
    }
  }

  void _show(String text, bool isError) {
    setState(() {
      _message = text;
      _messageIsError = isError;
    });
  }

  Widget _selectorPanel(BuildContext context) {
    final catalog = KnowledgeCatalog.instance;
    final bands = catalog.ageBands;
    final degrees = catalog.degrees;
    final domains = catalog.domains;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('提交类型'),
            const SizedBox(width: 12),
            ChoiceChip(
              key: const Key('sage_kind_knowledge'),
              label: const Text('新建知识'),
              selected: _kind == 'knowledge',
              onSelected: (value) => setState(() => _kind = 'knowledge'),
            ),
            const SizedBox(width: 10),
            ChoiceChip(
              key: const Key('sage_kind_point'),
              label: const Text('补充知识点'),
              selected: _kind == 'point',
              onSelected: (value) => setState(() => _kind = 'point'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<AgeBand>(
          key: const Key('sage_band'),
          initialValue: _band,
          items: [
            for (final band in bands)
              DropdownMenuItem(value: band, child: Text(band.label)),
          ],
          onChanged: (band) {
            setState(() => _band = band);
            // 当年龄档切换，清空下面的领域和概念。
            _domain = null;
            _degree = null;
            _concept = null;
          },
          decoration: const InputDecoration(
            labelText: '年龄档',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<StudyDegree>(
          key: const Key('sage_degree'),
          initialValue: _degree,
          items: [
            for (final degree in degrees)
              DropdownMenuItem(value: degree, child: Text(degree.label)),
          ],
          onChanged: (degree) {
            setState(() => _degree = degree);
            _domain = null;
            _concept = null;
          },
          decoration: const InputDecoration(
            labelText: '学习程度',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<LearningDomain>(
          key: const Key('sage_domain'),
          initialValue: _domain,
          items: [
            for (final domain in domains)
              DropdownMenuItem(
                value: domain,
                child: Text(domain.displayNameFor(_band ?? bands.first)),
              ),
          ],
          onChanged: (domain) {
            setState(() => _domain = domain);
            _concept = null;
          },
          decoration: const InputDecoration(
            labelText: '所属领域',
            border: OutlineInputBorder(),
          ),
        ),
        if (_kind == 'point') ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<Concept>(
            key: const Key('sage_concept'),
            initialValue: _concept,
            items: _domain == null || _band == null
                ? const <DropdownMenuItem<Concept>>[]
                : [
                    for (final concept in _domain!.conceptsFor(_band!))
                      DropdownMenuItem(
                        value: concept,
                        child: Text(concept.variantFor(_band!).topic),
                      ),
                  ],
            onChanged: (concept) => setState(() => _concept = concept),
            decoration: const InputDecoration(
              labelText: '补充到哪条知识',
              border: OutlineInputBorder(),
            ),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _topicController,
          key: const Key('sage_topic'),
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: '知识内容',
            hintText: '说出你想补充的那一条知识',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _doingController,
          key: const Key('sage_doing'),
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: '具体动作（可选）',
            hintText: '学习者做完就算完成的一件事',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _noteController,
          key: const Key('sage_note'),
          maxLength: 2000,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: '补充说明（可选）',
            hintText: '给本人或监护人的一句说明',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _contributionsPanel(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('我的贡献', style: TextStyle(fontWeight: FontWeight.bold)),
            if (_contributions.isNotEmpty)
              TextButton(
                key: const Key('sage_refresh'),
                onPressed: _reloadContributions,
                child: const Text('刷新'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_contributions.isEmpty)
          PaperCard(
            child: Text('还没有提交过知识，填好名字后就可以开始。',
                style: Theme.of(context).textTheme.bodySmall),
          )
        else
          ...[
            for (final c in _contributions)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _contributionCard(context, c),
              ),
          ],
      ],
    );
  }

  Widget _contributionCard(BuildContext context, SageContribution c) {
    final text = Theme.of(context).textTheme;
    final approved = c.status == 'approved';
    return PaperCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                c.kind == 'knowledge' ? '新建知识' : '补充知识点',
                style: text.titleSmall?.copyWith(
                  color: paperOchre,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              MasteryPill(
                label: approved ? '已审批' : '审批中',
                color: approved ? paperOchre : paperInkSoft,
              ),
              const Spacer(),
              Text(c.createdAt, style: text.bodySmall),
            ],
          ),
          const SizedBox(height: 6),
          Text(c.topic, style: text.bodyMedium),
          if (c.doing != null && c.doing!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('动作：${c.doing}', style: text.bodySmall),
          ],
          if (c.note != null && c.note!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('说明：${c.note}', style: text.bodySmall),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text('领域：${c.domainId ?? ''}  ·  年龄档：${c.ageBandId ?? ''}',
                  style: text.bodySmall),
              if (c.conceptId != null) ...[
                const SizedBox(width: 12),
                Text('知识：${c.conceptId}', style: text.bodySmall),
              ],
              if (c.position != null) ...[
                const SizedBox(width: 12),
                Text('位置：${c.position}', style: text.bodySmall),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('智者 · 添加知识')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            const PageHeader(
              title: '智者 · 添加知识',
              subtitle: '填好名字后，提交一条知识或补充一条知识点，审批后知识库里就能搜到。',
            ),
            const SizedBox(height: 16),
            PaperCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    key: const Key('sage_name_row'),
                    title: const Text('你的名字'),
                    subtitle: Text(
                      '这台设备的全部贡献都会显示这个名字',
                      style: text.bodySmall,
                    ),
                    trailing: _savingName
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check, color: paperOchre, size: 20),
                    onTap: _nameLoaded ? _saveName : null,
                  ),
                  const Divider(height: 1),
                  TextField(
                    controller: _nameController,
                    key: const Key('sage_name_input'),
                    maxLength: 40,
                    decoration: const InputDecoration(
                      labelText: '智者名',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _selectorPanel(context),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('sage_submit'),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('提交并写进知识库'),
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 10),
              PaperCard(
                color: _messageIsError
                    ? Colors.red.withValues(alpha: 0.1)
                    : paperOchre.withValues(alpha: 0.08),
                padding: const EdgeInsets.all(12),
                child: Text(
                  _message!,
                  style: text.bodyMedium?.copyWith(
                    color: _messageIsError ? Colors.red.shade700 : paperInk,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _contributionsPanel(context),
          ],
        ),
      ),
    );
  }
}
