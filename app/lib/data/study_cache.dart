import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 最近一次成功加载的整份数据。
class CachedStudy {
  const CachedStudy({
    required this.knowledge,
    required this.userData,
    required this.pending,
  });

  /// 知识库接口的原样 JSON。
  final Map<String, Object?> knowledge;

  /// 设备数据的原样 JSON。
  final Map<String, Object?> userData;

  /// 是否有还没同步到服务端的本地修改。
  final bool pending;
}

/// 缓存入口：应用只依赖这个接口，测试可以换成内存实现。
abstract class StudyCache {
  /// 读取缓存；没有或损坏时返回 null。
  Future<CachedStudy?> read();

  /// 写入一份缓存。
  Future<void> write({
    required Map<String, Object?> knowledge,
    required Map<String, Object?> userData,
    required bool pending,
  });

  /// 清除本机缓存文件；业务数据在服务端，删掉后联网会重新拉取。
  Future<void> clear();
}

/// 本机文件缓存：只存最近一次拉取的知识和用户数据，断网时兜底。
///
/// 应用本身不保存业务数据，缓存文件删掉也能重新拉取。
class FileStudyCache implements StudyCache {
  FileStudyCache({Directory? directory}) : _directory = directory;

  final Directory? _directory;

  Future<File> _file() async {
    final directory = _directory ?? await getApplicationDocumentsDirectory();
    return File('${directory.path}${Platform.pathSeparator}study_cache.json');
  }

  @override
  Future<CachedStudy?> read() async {
    final file = await _file();
    if (!await file.exists()) {
      return null;
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        return null;
      }
      final knowledge = decoded['knowledge'];
      final userData = decoded['userData'];
      if (knowledge is! Map || userData is! Map) {
        return null;
      }
      return CachedStudy(
        knowledge: Map<String, Object?>.from(knowledge),
        userData: Map<String, Object?>.from(userData),
        pending: decoded['pending'] == true,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write({
    required Map<String, Object?> knowledge,
    required Map<String, Object?> userData,
    required bool pending,
  }) async {
    final file = await _file();
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      jsonEncode({
        'version': 1,
        'knowledge': knowledge,
        'userData': userData,
        'pending': pending,
      }),
      flush: true,
    );
    if (await file.exists()) {
      await file.delete();
    }
    await temp.rename(file.path);
  }

  @override
  Future<void> clear() async {
    final file = await _file();
    if (await file.exists()) {
      await file.delete();
    }
  }
}
