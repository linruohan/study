import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 智者模块的远程接口错误。
class SageApiException implements Exception {
  SageApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 智者贡献：提交知识或知识点的记录。
class SageContribution {
  const SageContribution({
    required this.id,
    required this.kind,
    required this.domainId,
    required this.ageBandId,
    required this.degreeId,
    required this.conceptId,
    required this.position,
    required this.topic,
    required this.doing,
    required this.note,
    required this.status,
    required this.reviewedAt,
    required this.createdAt,
  });

  final String id;
  final String kind; // 'knowledge' 或 'point'
  final String? domainId;
  final String? ageBandId;
  final String? degreeId;
  final String? conceptId;
  final int? position;
  final String topic;
  final String? doing;
  final String? note;
  final String status; // 'pending' | 'approved'
  final String? reviewedAt;
  final String createdAt;

  factory SageContribution.fromJson(Map<String, Object?> json) {
    return SageContribution(
      id: json['id'] as String,
      kind: json['kind'] as String,
      domainId: json['domainId'] as String?,
      ageBandId: json['ageBandId'] as String?,
      degreeId: json['degreeId'] as String?,
      conceptId: json['conceptId'] as String?,
      position: json['position'] as int?,
      topic: json['topic'] as String,
      doing: json['doing'] as String?,
      note: json['note'] as String?,
      status: json['status'] as String,
      reviewedAt: json['reviewedAt'] as String?,
      createdAt: json['createdAt'] as String,
    );
  }
}

/// 智者名：同一台设备的全部贡献都显示这个名字。
class SageName {
  const SageName({required this.name});
  final String name;

  factory SageName.fromJson(Map<String, Object?> json) {
    return SageName(name: json['name'] as String? ?? '');
  }
}

/// 智者模块的远程接口：填名字、看贡献、提交知识或知识点。
abstract class SageApi {
  /// 读取智者名与已提交的贡献列表。
  Future<({SageName name, List<SageContribution> contributions})>
      fetchSage(String deviceId);

  /// 保存或更新智者名。
  Future<SageName> saveSageName(String deviceId, String name);

  /// 提交一条知识或知识点贡献；服务端直接审批并写回知识库。
  Future<SageContribution> createContribution(
    String deviceId, {
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

/// 默认实现：访问本地服务，地址与 StudyApi 保持一致。
class HttpSageApi implements SageApi {
  HttpSageApi({String? baseUrl, HttpClient? client})
      : _baseUrl = (baseUrl ??
                const String.fromEnvironment(
                  'API_BASE_URL',
                  defaultValue: 'http://127.0.0.1:3000',
                ))
            .replaceAll(RegExp(r'/+$'), ''),
          _client = client ?? HttpClient();

  static const _timeout = Duration(seconds: 8);
  final String _baseUrl;
  final HttpClient _client;

  @override
  Future<({SageName name, List<SageContribution> contributions})>
      fetchSage(String deviceId) async {
    final decoded = await _request('GET', '/api/devices/$deviceId/sage');
    final rawName = decoded['name'];
    final rawContributions = decoded['contributions'];
    final contributions = <SageContribution>[];
    if (rawContributions is List) {
      for (final item in rawContributions) {
        if (item is Map) {
          contributions.add(
            SageContribution.fromJson(Map<String, Object?>.from(item)),
          );
        }
      }
    }
    return (
      name: SageName.fromJson(
        Map<String, Object?>.from(rawName as Map? ?? <String, Object?>{}),
      ),
      contributions: contributions,
    );
  }

  @override
  Future<SageName> saveSageName(String deviceId, String name) async {
    final decoded = await _request(
      'PUT',
      '/api/devices/$deviceId/sage',
      body: {'name': name},
    );
    return SageName.fromJson(Map<String, Object?>.from(decoded));
  }

  @override
  Future<SageContribution> createContribution(
    String deviceId, {
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
    final decoded = await _request(
      'POST',
      '/api/devices/$deviceId/sage/contributions',
      body: {
        'kind': kind,
        'domainId': domainId,
        'ageBandId': ageBandId,
        'degreeId': degreeId,
        'conceptId': conceptId,
        'position': position,
        'topic': topic,
        'doing': doing,
        'note': note,
      },
    );
    return SageContribution.fromJson(Map<String, Object?>.from(decoded['contribution'] as Map));
  }

  Future<Map<String, Object?>> _request(
    String method,
    String path, {
    Object? body,
  }) async {
    try {
      final request = await _client
          .openUrl(method, Uri.parse('$_baseUrl$path'))
          .timeout(_timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close().timeout(_timeout);
      final text = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw SageApiException(_errorMessage(text, response.statusCode));
      }
      final decoded = jsonDecode(text);
      if (decoded is! Map) {
        throw SageApiException('接口返回格式不对');
      }
      return Map<String, Object?>.from(decoded);
    } on SageApiException {
      rethrow;
    } on SocketException {
      throw SageApiException('连不上本地服务，请确认服务已启动');
    } on TimeoutException {
      throw SageApiException('请求超时，请稍后再试');
    } on FormatException {
      throw SageApiException('接口返回的内容无法解析');
    } on HttpException {
      throw SageApiException('网络请求失败，请稍后再试');
    }
  }

  String _errorMessage(String body, int statusCode) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map && error['message'] is String) {
          return error['message'] as String;
        }
      }
    } catch (_) {
      return '服务返回错误（$statusCode）';
    }
    return '服务返回错误（$statusCode）';
  }
}
