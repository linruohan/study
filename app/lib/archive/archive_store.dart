import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../data/study_repository.dart';
import 'archive_file.dart';
import 'learning_record.dart';

/// 学习档案的读写入口：数据在数据库里，界面只和它打交道。
///
/// 导出仍然生成本机文件，方便用户自己留一份。
class ArchiveStore {
  ArchiveStore(this._repository, {Directory? directory})
      : _directory = directory;

  final StudyRepository _repository;
  final Directory? _directory;

  /// 读取整份档案。
  Future<ArchiveFile> load() async => _repository.archive;

  /// 覆盖保存整份档案。
  Future<void> save(ArchiveFile archive) {
    return _repository.saveArchive(archive);
  }

  /// 导出当前档案的副本到文档目录。
  Future<File> exportCopy() async {
    final directory = _directory ?? await getApplicationDocumentsDirectory();
    final stamped = DateTime.now().toIso8601String().replaceAll(':', '-');
    final copy = File(
      '${directory.path}${Platform.pathSeparator}study_archive_$stamped.json',
    );
    await copy.writeAsString(_repository.archive.toJsonString(), flush: true);
    return copy;
  }

  /// 追加一条练习记录。
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

  /// 追加一条监护人观察。
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

  /// 追加一条记录：先更新内存和缓存，再同步数据库。
  Future<ArchiveFile> addRecord({
    required String source,
    required String subject,
    required String body,
    DateTime? at,
    String? conceptId,
    String? domainId,
    String? ageBandId,
  }) async {
    final now = at ?? DateTime.now();
    final record = LearningRecord(
      id: now.microsecondsSinceEpoch.toString(),
      at: now,
      source: source,
      subject: subject,
      body: body,
      conceptId: conceptId,
      domainId: domainId,
      ageBandId: ageBandId,
    );
    final next = _repository.archive.add(record);
    await _repository.saveArchive(next);
    return next;
  }
}
