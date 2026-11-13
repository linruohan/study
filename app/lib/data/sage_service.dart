import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'sage_api.dart';

/// 智者模块：填名字、看贡献、提交知识或知识点。
///
/// 智者名按设备持久化在本机文件里，先写本机，再同步到服务端；断网时本机可读。
abstract class SageService {
  /// 当前设备的智者名；还没填就返回空字符串。
  Future<String> name();

  /// 保存智者名；同步到服务端，失败时记为待推送。
  Future<void> saveName(String name);

  /// 读取当前设备的全部贡献，新的在前。
  Future<List<SageContribution>> contributions();

  /// 提交一条知识（新建知识节点）或知识点（补充到已有知识节点）。
  Future<SageContribution> createContribution({
    required String kind,
    required String domainId,
    required String ageBandId,
    required String degreeId,
    String? conceptId,
    int? position,
    required String topic,
    String? doing,
    String? note,
  });
}

/// 默认实现：本机文件存名字与贡献，远程接口做同步。
class HttpSageService implements SageService {
  HttpSageService({
    required this.api,
    required this.deviceId,
    Directory? directory,
  }) : _directory = directory;

  final SageApi api;
  final String deviceId;
  final Directory? _directory;

  String? _sageName;
  List<SageContribution> _contributions = const [];
  bool _pendingName = false;
  bool _pendingList = false;

  Future<File> _file() async {
    final directory = _directory ?? await getApplicationDocumentsDirectory();
    return File('${directory.path}${Platform.pathSeparator}study_sage.json');
  }

  Future<void> _writeCache() async {
    final file = await _file();
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      jsonEncode({
        'version': 1,
        'deviceId': deviceId,
        'name': _sageName,
        'pendingName': _pendingName,
        'pendingList': _pendingList,
        'contributions': [
          for (final c in _contributions)
            {
              'id': c.id,
              'kind': c.kind,
              'domainId': c.domainId,
              'ageBandId': c.ageBandId,
              'degreeId': c.degreeId,
              'conceptId': c.conceptId,
              'position': c.position,
              'topic': c.topic,
              'doing': c.doing,
              'note': c.note,
              'status': c.status,
              'reviewedAt': c.reviewedAt,
              'createdAt': c.createdAt,
            },
        ],
      }),
      flush: true,
    );
    if (await file.exists()) {
      await file.delete();
    }
    await temp.rename(file.path);
  }

  Future<void> _readCache() async {
    final file = await _file();
    if (!await file.exists()) {
      return;
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        return;
      }
      _sageName = decoded['name'] as String?;
      _pendingName = decoded['pendingName'] == true;
      _pendingList = decoded['pendingList'] == true;
      final raw = decoded['contributions'];
      if (raw is List) {
        _contributions = [
          for (final item in raw)
            if (item is Map)
              SageContribution(
                id: item['id'] as String? ?? '',
                kind: item['kind'] as String? ?? '',
                domainId: item['domainId'] as String?,
                ageBandId: item['ageBandId'] as String?,
                degreeId: item['degreeId'] as String?,
                conceptId: item['conceptId'] as String?,
                position: item['position'] as int?,
                topic: item['topic'] as String? ?? '',
                doing: item['doing'] as String?,
                note: item['note'] as String?,
                status: item['status'] as String? ?? 'pending',
                reviewedAt: item['reviewedAt'] as String?,
                createdAt: item['createdAt'] as String? ?? '',
              ),
        ];
      }
    } catch (_) {
      // 缓存损坏时当作没有。
    }
  }

  @override
  Future<String> name() async {
    if (_sageName != null) {
      return _sageName!;
    }
    await _readCache();
    if (_sageName != null) {
      return _sageName!;
    }
    try {
      final result = await api.fetchSage(deviceId);
      _sageName = result.name.name;
      _contributions = result.contributions;
      _pendingName = false;
      _pendingList = false;
      await _writeCache();
      return result.name.name;
    } catch (_) {
      _sageName ??= '';
      return _sageName!;
    }
  }

  @override
  Future<void> saveName(String name) async {
    _sageName = name;
    _pendingName = true;
    await _writeCache();
    try {
      await api.saveSageName(deviceId, name);
      _pendingName = false;
      await _writeCache();
    } catch (_) {
      // 断网时保留本机值，下次启动再推。
      _pendingName = true;
    }
  }

  @override
  Future<List<SageContribution>> contributions() async {
    if (_pendingList) {
      return List.unmodifiable(_contributions);
    }
    try {
      final result = await api.fetchSage(deviceId);
      _contributions = result.contributions;
      _sageName ??= result.name.name;
      _pendingList = false;
      await _writeCache();
      return List.unmodifiable(_contributions);
    } catch (_) {
      await _readCache();
      return List.unmodifiable(_contributions);
    }
  }

  @override
  Future<SageContribution> createContribution({
    required String kind,
    required String domainId,
    required String ageBandId,
    required String degreeId,
    String? conceptId,
    int? position,
    required String topic,
    String? doing,
    String? note,
  }) async {
    final contribution = await api.createContribution(
      deviceId,
      kind: kind,
      domainId: domainId,
      ageBandId: ageBandId,
      degreeId: degreeId,
      conceptId: conceptId,
      position: position,
      topic: topic,
      doing: doing,
      note: note,
    );
    _contributions = [contribution, ..._contributions];
    _pendingList = true;
    await _writeCache();
    return contribution;
  }
}
