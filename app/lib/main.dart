import 'package:flutter/material.dart';

import 'archive/local_archive.dart';

void main() {
  runApp(const StudyApp());
}

class StudyApp extends StatelessWidget {
  const StudyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '学习',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8C4A2F)),
        useMaterial3: true,
      ),
      home: const TodayPage(),
    );
  }
}

class TodayPage extends StatefulWidget {
  const TodayPage({super.key, this.archive});

  final LocalArchive? archive;

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  late final LocalArchive _archive = widget.archive ?? LocalArchive();
  var _done = false;
  var _count = 0;
  String? _exportPath;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    final archive = await _archive.load();
    if (!mounted) {
      return;
    }
    setState(() => _count = archive.records.length);
  }

  Future<void> _tapSun() async {
    final saved = await _archive.addPractice(
      subject: '语',
      body: '指出太阳是「日」',
    );
    setState(() {
      _done = true;
      _count = saved.records.length;
      _exportPath = null;
    });
  }

  Future<void> _export() async {
    final file = await _archive.exportCopy();
    setState(() => _exportPath = file.path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F1E7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _done ? '你能指出太阳是「日」' : '点一点太阳',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 32),
              Expanded(
                child: GestureDetector(
                  key: const Key('sun'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _tapSun,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFFE2A100),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '日',
                        style: TextStyle(fontSize: 96, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '本机记录 $_count 条',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _export,
                child: const Text('导出档案到本机'),
              ),
              if (_exportPath != null) ...[
                const SizedBox(height: 8),
                Text(_exportPath!, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
