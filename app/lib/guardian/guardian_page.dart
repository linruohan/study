import 'package:flutter/material.dart';

import '../archive/archive_store.dart';
import 'care_guidance.dart';
import 'care_note.dart';
import '../ui/theme.dart';

/// 监护人观察页：愿意记就记一条，空着也不问责。
///
/// 提醒只接着记下的那一条，并声明不能代替老师、咨询师或医生。
class GuardianPage extends StatefulWidget {
  const GuardianPage({super.key, required this.archive});

  final ArchiveStore archive;

  @override
  State<GuardianPage> createState() => _GuardianPageState();
}

class _GuardianPageState extends State<GuardianPage> {
  String? _saved;
  CareGuidance? _guidance;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final archive = await widget.archive.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _guidance = CareGuidance.fromRecords(archive.records);
    });
  }

  /// 记一条监护人观察，同时更新给监护人的提醒。
  Future<void> _save(CareNote note) async {
    if (_busy) {
      return;
    }
    _busy = true;
    final saved = await widget.archive.addObservation(body: note.body);
    if (!mounted) {
      return;
    }
    setState(() {
      _saved = note.body;
      _busy = false;
      _guidance = CareGuidance.fromRecords(saved.records);
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('监护人观察')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              _saved == null ? '愿意记的话' : '记下了：$_saved',
              style: text.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _saved == null
                  ? '可以空着。空着不是落后。这是监护人的观察，不是孩子自己说的。'
                  : '这是监护人的观察，不是孩子自己说的。',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 20),
            for (final note in CareNote.choices)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PaperCard(
                  onTap: _saved == null ? () => _save(note) : null,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(note.body, style: text.titleMedium),
                      ),
                      if (_saved == note.body)
                        const Icon(
                          Icons.check,
                          size: 18,
                          color: paperOchre,
                        ),
                    ],
                  ),
                ),
              ),
            if (_guidance != null) ...[
              const SizedBox(height: 8),
              Text('给监护人的提醒', style: text.titleMedium),
              const SizedBox(height: 10),
              PaperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_guidance!.what),
                    const SizedBox(height: 6),
                    Text(_guidance!.howLong),
                    const SizedBox(height: 6),
                    Text(_guidance!.basis),
                    const SizedBox(height: 6),
                    Text(_guidance!.alternative),
                    const SizedBox(height: 10),
                    Text(_guidance!.reflection, style: text.bodySmall),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(CareGuidance.footer, style: text.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
