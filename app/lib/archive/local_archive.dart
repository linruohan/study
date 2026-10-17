import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'archive_file.dart';
import 'learning_record.dart';

class LocalArchive {
  LocalArchive({Directory? directory}) : _directory = directory;

  final Directory? _directory;

  Future<Directory> _dir() async {
    return _directory ?? await getApplicationDocumentsDirectory();
  }

  Future<File> _file() async {
    final dir = await _dir();
    return File('${dir.path}${Platform.pathSeparator}study_archive.json');
  }

  Future<ArchiveFile> load() async {
    final file = await _file();
    if (!file.existsSync()) {
      return const ArchiveFile(records: []);
    }
    return ArchiveFile.parse(await file.readAsString());
  }

  Future<void> save(ArchiveFile archive) async {
    final file = await _file();
    await file.writeAsString(archive.toJsonString());
  }

  Future<File> exportCopy() async {
    final source = await _file();
    if (!source.existsSync()) {
      await save(const ArchiveFile(records: []));
    }
    final dir = await _dir();
    final stamped = DateTime.now().toIso8601String().replaceAll(':', '-');
    final copy = File(
      '${dir.path}${Platform.pathSeparator}study_archive_$stamped.json',
    );
    return source.copy(copy.path);
  }

  Future<ArchiveFile> addPractice({
    required String subject,
    required String body,
    DateTime? at,
  }) async {
    final current = await load();
    final now = at ?? DateTime.now();
    final next = current.add(
      LearningRecord(
        id: now.microsecondsSinceEpoch.toString(),
        at: now,
        source: '应用内练习',
        subject: subject,
        body: body,
      ),
    );
    await save(next);
    return next;
  }
}
