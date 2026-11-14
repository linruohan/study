import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 已读消息 id 的存取入口；测试可以换成内存实现。
abstract class MessageReadStore {
  Future<Set<String>> load();
  Future<void> save(Set<String> ids);
}

/// 本机文件实现：已读 id 存 message_reads.json，重启后不再重复提醒。
class FileMessageReadStore implements MessageReadStore {
  FileMessageReadStore({Directory? directory}) : _directory = directory;

  final Directory? _directory;

  @override
  Future<Set<String>> load() async {
    try {
      final directory = _directory ?? await getApplicationDocumentsDirectory();
      final file = File('${directory.path}${Platform.pathSeparator}message_reads.json');
      if (!await file.exists()) {
        return <String>{};
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is List) {
        return {for (final item in decoded) if (item is String) item};
      }
    } catch (_) {
      // 坏文件当作没有已读记录。
    }
    return <String>{};
  }

  @override
  Future<void> save(Set<String> ids) async {
    try {
      final directory = _directory ?? await getApplicationDocumentsDirectory();
      final file = File('${directory.path}${Platform.pathSeparator}message_reads.json');
      await file.writeAsString(jsonEncode(ids.toList()), flush: true);
    } catch (_) {
      // 保存失败只影响「重启后再提醒一次」，不阻塞界面。
    }
  }
}
