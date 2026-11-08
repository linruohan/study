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
    return ArchiveFile.parse(file.readAsStringSync());
  }

  Future<void> save(ArchiveFile archive) async {
    final file = await _file();
    file.writeAsStringSync(archive.toJsonString());
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
    source.copySync(copy.path);
    return copy;
  }

  Future<ArchiveFile> addPractice({
    required String subject,
    required String body,
    DateTime? at,
    String? conceptId,
    String? domainId,
    String? ageBandId,
  }) {
    return addRecord(
      source: '应用内练习',
      subject: subject,
      body: body,
      at: at,
      conceptId: conceptId,
      domainId: domainId,
      ageBandId: ageBandId,
    );
  }

  Future<ArchiveFile> addObservation({
    required String body,
    DateTime? at,
  }) {
    return addRecord(
      source: '监护人观察',
      subject: '照护',
      body: body,
      at: at,
    );
  }

  Future<ArchiveFile> addRecord({
    required String source,
    required String subject,
    required String body,
    DateTime? at,
    String? conceptId,
    String? domainId,
    String? ageBandId,
  }) async {
    final current = await load();
    final now = at ?? DateTime.now();
    final next = current.add(
      LearningRecord(
        id: now.microsecondsSinceEpoch.toString(),
        at: now,
        source: source,
        subject: subject,
        body: body,
        conceptId: conceptId,
        domainId: domainId,
        ageBandId: ageBandId,
      ),
    );
    await save(next);
    return next;
  }
}
