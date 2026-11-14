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

  /// 列出文档目录里已有的导出副本，按修改时间从新到旧。
  Future<List<File>> listExportedCopies() async {
    final directory = _directory ?? await getApplicationDocumentsDirectory();
    final files = <File>[];
    await for (final entity in directory.list()) {
      if (entity is File &&
          entity.path.contains('study_archive_') &&
          entity.path.endsWith('.json')) {
        files.add(entity);
      }
    }
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  /// 从导出副本导入整份档案：先校验格式与版本，再整份替换并同步数据库。
  ///
  /// 导入会覆盖当前档案，调用方须先向用户确认。
  Future<ArchiveFile> importCopy(File file) async {
    final raw = await file.readAsString();
    final archive = ArchiveFile.parse(raw); // 格式或版本不对会抛 FormatException。
    await _repository.saveArchive(archive);
    return _repository.archive;
  }

  /// 追加一条练习记录。
  Future<ArchiveFile> addPractice({
    required String subject,
    required String body,
    DateTime? at,
    String? conceptId,
    String? categoryId,
    String? ageBandId,
  }) {
    return addRecord(
      source: '应用内练习',
      subject: subject,
      body: body,
      at: at,
      conceptId: conceptId,
      categoryId: categoryId,
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
    String? categoryId,
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
      categoryId: categoryId,
      ageBandId: ageBandId,
    );
    final next = _repository.archive.add(record);
    await _repository.saveArchive(next);
    // 保存后仓库会回读数据库，这里返回回读到的档案，页面展示以库为准。
    return _repository.archive;
  }
}
