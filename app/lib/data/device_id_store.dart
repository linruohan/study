import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

/// 设备标识入口：应用只依赖这个接口，测试可以换成内存实现。
abstract class DeviceIdStore {
  /// 读取设备 id；没有时生成一个并保存。
  Future<String> read();
}

/// 本机文件设备标识：第一次启动生成 UUID，之后一直复用。
///
/// 这是应用端唯一必须本地保存的数据，用来区分数据库里的用户数据。
class FileDeviceIdStore implements DeviceIdStore {
  FileDeviceIdStore({Directory? directory}) : _directory = directory;

  final Directory? _directory;

  @override
  Future<String> read() async {
    final directory = _directory ?? await getApplicationDocumentsDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}device_id.txt');
    if (await file.exists()) {
      final text = (await file.readAsString()).trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    final id = _newUuid();
    await file.writeAsString(id, flush: true);
    return id;
  }

  /// 生成 UUID v4，不额外引入依赖。
  String _newUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
