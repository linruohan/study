import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'auth_session.dart';

/// 接口错误：带上可读信息，启动页直接展示。
class StudyApiException implements Exception {
  StudyApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 远程数据接口：知识库整包，以及按设备读写的业务数据整包。
abstract class StudyApi {
  Future<Map<String, dynamic>> fetchKnowledge();
  Future<Map<String, dynamic>> fetchUserData(String deviceId);
  Future<Map<String, dynamic>> saveUserData(String deviceId, Map<String, dynamic> data);

  Future<List<Map<String, dynamic>>> fetchPointComments({
    required String conceptId,
    required String ageBandId,
    required String degreeId,
    required int position,
    int? limit,
    int? offset,
  });
  Future<Map<String, dynamic>> createPointComment({
    required String conceptId,
    required String ageBandId,
    required String degreeId,
    required int position,
    required String deviceId,
    required String body,
  });
  Future<List<Map<String, dynamic>>> fetchPointCorrections({
    required String conceptId,
    required String ageBandId,
    required String degreeId,
    required int position,
    int? limit,
    int? offset,
  });
  Future<Map<String, dynamic>> createPointCorrection({
    required String conceptId,
    required String ageBandId,
    required String degreeId,
    required int position,
    required String deviceId,
    required String body,
    String? suggestedText,
  });

  /// 创建知识分类/子类型（可嵌套）。
  Future<Map<String, dynamic>> createCategory({
    required String id,
    String? parentId,
    required String name,
    String question = '',
    String glyph = '类',
    String color = '#7A6A54',
  });

  /// 修改分类的名称与描述。
  Future<Map<String, dynamic>> updateCategory({
    required String id,
    required String name,
    String question = '',
  });

  /// 在某个分类下创建一条知识（概念 + 当前年龄档呈现 + 默认知识点）。
  Future<Map<String, dynamic>> createKnowledge({
    required String categoryId,
    required String ageBandId,
    required String topic,
    String? doing,
    String? praise,
    String? check,
    String? answer,
    String? note,
    String? glyph,
  });

  /// 在某条知识的某个学习程度下追加一个知识点；可标注认知层级。
  Future<Map<String, dynamic>> addKnowledgePoint({
    required String conceptId,
    required String ageBandId,
    required String degreeId,
    required String point,
    String? cognitiveLevel,
  });

  /// 审核知识点纠错（通过可发放积分）。
  Future<Map<String, dynamic>> reviewPointCorrection({
    required String correctionId,
    required String reviewerDeviceId,
    required bool approve,
    int points = 0,
  });

  /// 知识点章节列表。
  Future<List<Map<String, dynamic>>> fetchPointChapters({
    required String conceptId,
    required String ageBandId,
    required String degreeId,
    required int pointPosition,
  });

  /// 为知识点新增章节。
  Future<Map<String, dynamic>> createPointChapter({
    required String conceptId,
    required String ageBandId,
    required String degreeId,
    required int pointPosition,
    required String title,
    String? content,
  });

  /// 更新知识点章节。
  Future<Map<String, dynamic>> updatePointChapter({
    required String conceptId,
    required String ageBandId,
    required String degreeId,
    required int pointPosition,
    required int chapterPosition,
    required String title,
    String? content,
  });

  /// 删除知识点章节（服务端会重排后续章节序号）。
  Future<void> deletePointChapter({
    required String conceptId,
    required String ageBandId,
    required String degreeId,
    required int pointPosition,
    required int chapterPosition,
  });

  /// 当前设备积分余额与流水。
  Future<Map<String, dynamic>> fetchPointCredits(String deviceId, {int? limit, int? offset});

  /// 全局待审核纠错列表。
  Future<List<Map<String, dynamic>>> fetchPendingPointCorrections({int? limit, int? offset});

  /// 学位申请列表（仅管理员；status: pending/approved/rejected/all）。
  Future<List<Map<String, dynamic>>> fetchDegreeApplications({String status = 'pending'});

  /// 审核学位申请，通过即把申请人境界提升到目标境界（仅管理员）。
  Future<Map<String, dynamic>> reviewDegreeApplication({
    required String applicationId,
    required bool approve,
  });
}

/// 默认实现：访问本地服务。
///
/// 地址可以用 `--dart-define=API_BASE_URL=http://...` 覆盖，
/// 默认连接本机 3000 端口。
class HttpStudyApi implements StudyApi {
  HttpStudyApi({String? baseUrl, HttpClient? client})
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
  Future<Map<String, dynamic>> fetchKnowledge() {
    return _request('GET', '/api/knowledge');
  }

  @override
  Future<Map<String, dynamic>> fetchUserData(String deviceId) {
    return _request('GET', '/api/devices/$deviceId/data');
  }

  @override
  Future<Map<String, dynamic>> saveUserData(
    String deviceId,
    Map<String, dynamic> data,
  ) {
    return _request('PUT', '/api/devices/$deviceId/data', body: data);
  }



  @override
  Future<Map<String, dynamic>> createCategory({
    required String id,
    String? parentId,
    required String name,
    String question = '',
    String glyph = '类',
    String color = '#7A6A54',
  }) async {
    final map = await _request('POST', '/api/knowledge/categories', body: {
      'id': id,
      'parentId': parentId,
      'name': name,
      'question': question,
      'glyph': glyph,
      'color': color,
    });
    final category = map['category'];
    return category is Map ? Map<String, dynamic>.from(category) : map;
  }

  @override
  Future<Map<String, dynamic>> updateCategory({
    required String id,
    required String name,
    String question = '',
  }) async {
    final map = await _request('PATCH', '/api/knowledge/categories/$id', body: {
      'name': name,
      'question': question,
    });
    final category = map['category'];
    return category is Map ? Map<String, dynamic>.from(category) : map;
  }

  @override
  Future<Map<String, dynamic>> createKnowledge({
    required String categoryId,
    required String ageBandId,
    required String topic,
    String? doing,
    String? praise,
    String? check,
    String? answer,
    String? note,
    String? glyph,
  }) async {
    final map = await _request('POST', '/api/knowledge/concepts', body: {
      'categoryId': categoryId,
      'ageBandId': ageBandId,
      'topic': topic,
      if (doing != null && doing.isNotEmpty) 'doing': doing,
      if (praise != null && praise.isNotEmpty) 'praise': praise,
      if (check != null && check.isNotEmpty) 'check': check,
      if (answer != null && answer.isNotEmpty) 'answer': answer,
      if (note != null && note.isNotEmpty) 'note': note,
      if (glyph != null && glyph.isNotEmpty) 'glyph': glyph,
    });
    final concept = map['concept'];
    return concept is Map ? Map<String, dynamic>.from(concept) : map;
  }

  @override
  Future<Map<String, dynamic>> addKnowledgePoint({
    required String conceptId,
    required String ageBandId,
    required String degreeId,
    required String point,
    String? cognitiveLevel,
  }) async {
    final map = await _request('POST', '/api/knowledge/points', body: {
      'conceptId': conceptId,
      'ageBandId': ageBandId,
      'degreeId': degreeId,
      'point': point,
      if (cognitiveLevel != null) 'cognitiveLevel': cognitiveLevel,
    });
    final created = map['point'];
    return created is Map ? Map<String, dynamic>.from(created) : map;
  }

  Map<String, String> _pointQuery({
    required String conceptId,
    required String ageBandId,
    required String degreeId,
    required int position,
  }) => {
        'conceptId': conceptId,
        'ageBandId': ageBandId,
        'degreeId': degreeId,
        'position': '$position',
      };

  @override
  Future<List<Map<String, dynamic>>> fetchPointComments({
    required String conceptId,
    required String ageBandId,
    required String degreeId,
    required int position,
    int? limit,
    int? offset,
  }) async {
    final qp = {..._pointQuery(conceptId: conceptId, ageBandId: ageBandId, degreeId: degreeId, position: position)};
    if (limit != null) qp['limit'] = '$limit';
    if (offset != null) qp['offset'] = '$offset';
    final uri = Uri.parse('$_baseUrl/api/knowledge/points/comments').replace(queryParameters: qp);
    final map = await _requestUri('GET', uri);
    final list = map['comments'];
    if (list is! List) return const [];
    return [for (final item in list) if (item is Map) Map<String, dynamic>.from(item)];
  }

  @override
  Future<Map<String, dynamic>> createPointComment({
    required String conceptId,
    required String ageBandId,
    required String degreeId,
    required int position,
    required String deviceId,
    required String body,
  }) async {
    final map = await _request('POST', '/api/knowledge/points/comments', body: {
      ..._pointQuery(conceptId: conceptId, ageBandId: ageBandId, degreeId: degreeId, position: position),
      'deviceId': deviceId,
      'body': body,
    });
    final comment = map['comment'];
    return comment is Map ? Map<String, dynamic>.from(comment) : map;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPointCorrections({
    required String conceptId,
    required String ageBandId,
    required String degreeId,
    required int position,
    int? limit,
    int? offset,
  }) async {
    final qp = {..._pointQuery(conceptId: conceptId, ageBandId: ageBandId, degreeId: degreeId, position: position)};
    if (limit != null) qp['limit'] = '$limit';
    if (offset != null) qp['offset'] = '$offset';
    final uri = Uri.parse('$_baseUrl/api/knowledge/points/corrections').replace(queryParameters: qp);
    final map = await _requestUri('GET', uri);
    final list = map['corrections'];
    if (list is! List) return const [];
    return [for (final item in list) if (item is Map) Map<String, dynamic>.from(item)];
  }

  @override
  Future<Map<String, dynamic>> createPointCorrection({
    required String conceptId,
    required String ageBandId,
    required String degreeId,
    required int position,
    required String deviceId,
    required String body,
    String? suggestedText,
  }) async {
    final payload = <String, Object?>{
      ..._pointQuery(conceptId: conceptId, ageBandId: ageBandId, degreeId: degreeId, position: position),
      'deviceId': deviceId,
      'body': body,
      'suggestedText': suggestedText,
    };
    final map = await _request('POST', '/api/knowledge/points/corrections', body: payload);
    final correction = map['correction'];
    return correction is Map ? Map<String, dynamic>.from(correction) : map;
  }

  @override
  Future<Map<String, dynamic>> reviewPointCorrection({
    required String correctionId,
    required String reviewerDeviceId,
    required bool approve,
    int points = 0,
  }) async {
    final map = await _request('POST', '/api/knowledge/points/corrections/review', body: {
      'correctionId': correctionId,
      'reviewerDeviceId': reviewerDeviceId,
      'approve': approve,
      'points': points,
    });
    final correction = map['correction'];
    return correction is Map ? Map<String, dynamic>.from(correction) : map;
  }

  Map<String, String> _chapterQuery({
    required String conceptId,
    required String ageBandId,
    required String degreeId,
    required int pointPosition,
  }) => {
        'conceptId': conceptId,
        'ageBandId': ageBandId,
        'degreeId': degreeId,
        'pointPosition': '$pointPosition',
      };

  @override
  Future<List<Map<String, dynamic>>> fetchPointChapters({
    required String conceptId,
    required String ageBandId,
    required String degreeId,
    required int pointPosition,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/knowledge/points/chapters').replace(
      queryParameters: _chapterQuery(conceptId: conceptId, ageBandId: ageBandId, degreeId: degreeId, pointPosition: pointPosition),
    );
    final map = await _requestUri('GET', uri);
    final list = map['chapters'];
    if (list is! List) return const [];
    return [for (final item in list) if (item is Map) Map<String, dynamic>.from(item)];
  }

  @override
  Future<Map<String, dynamic>> createPointChapter({
    required String conceptId,
    required String ageBandId,
    required String degreeId,
    required int pointPosition,
    required String title,
    String? content,
  }) async {
    final map = await _request('POST', '/api/knowledge/points/chapters', body: {
      ..._chapterQuery(conceptId: conceptId, ageBandId: ageBandId, degreeId: degreeId, pointPosition: pointPosition),
      'title': title,
      'content': content,
    });
    final chapter = map['chapter'];
    return chapter is Map ? Map<String, dynamic>.from(chapter) : map;
  }

  @override
  Future<Map<String, dynamic>> updatePointChapter({
    required String conceptId,
    required String ageBandId,
    required String degreeId,
    required int pointPosition,
    required int chapterPosition,
    required String title,
    String? content,
  }) async {
    final map = await _request('PUT', '/api/knowledge/points/chapters', body: {
      ..._chapterQuery(conceptId: conceptId, ageBandId: ageBandId, degreeId: degreeId, pointPosition: pointPosition),
      'chapterPosition': chapterPosition,
      'title': title,
      'content': content,
    });
    final chapter = map['chapter'];
    return chapter is Map ? Map<String, dynamic>.from(chapter) : map;
  }

  @override
  Future<void> deletePointChapter({
    required String conceptId,
    required String ageBandId,
    required String degreeId,
    required int pointPosition,
    required int chapterPosition,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/knowledge/points/chapters').replace(
      queryParameters: {
        ..._chapterQuery(conceptId: conceptId, ageBandId: ageBandId, degreeId: degreeId, pointPosition: pointPosition),
        'chapterPosition': '$chapterPosition',
      },
    );
    await _requestUri('DELETE', uri);
  }

  @override
  Future<Map<String, dynamic>> fetchPointCredits(String deviceId, {int? limit, int? offset}) async {
    final qp = <String, String>{'deviceId': deviceId};
    if (limit != null) qp['limit'] = '$limit';
    if (offset != null) qp['offset'] = '$offset';
    final uri = Uri.parse('$_baseUrl/api/knowledge/points/credits').replace(queryParameters: qp);
    return _requestUri('GET', uri);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPendingPointCorrections({int? limit, int? offset}) async {
    final qp = <String, String>{};
    if (limit != null) qp['limit'] = '$limit';
    if (offset != null) qp['offset'] = '$offset';
    final uri = Uri.parse('$_baseUrl/api/knowledge/points/corrections/pending')
        .replace(queryParameters: qp.isEmpty ? null : qp);
    final map = await _requestUri('GET', uri);
    final list = map['corrections'];
    if (list is! List) return const [];
    return [for (final item in list) if (item is Map) Map<String, dynamic>.from(item)];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchDegreeApplications({String status = 'pending'}) async {
    final uri = Uri.parse('$_baseUrl/api/degree/applications')
        .replace(queryParameters: {'status': status});
    final map = await _requestUri('GET', uri);
    final list = map['applications'];
    if (list is! List) return const [];
    return [for (final item in list) if (item is Map) Map<String, dynamic>.from(item)];
  }

  @override
  Future<Map<String, dynamic>> reviewDegreeApplication({
    required String applicationId,
    required bool approve,
  }) {
    return _request('POST', '/api/degree/applications/$applicationId/review', body: {
      'approve': approve,
    });
  }


  Future<Map<String, dynamic>> _request(String method, String path, {Object? body}) {
    return _requestUri(method, Uri.parse('$_baseUrl$path'), body: body);
  }

  Future<Map<String, dynamic>> _requestUri(String method, Uri uri, {Object? body}) async {
    try {
      final request = await _client.openUrl(method, uri).timeout(_timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      // 已登录时带上会话 token；服务端据此判断管理员权限。
      final token = AuthSession.token;
      if (token != null && token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
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
        throw StudyApiException(_errorMessage(text, response.statusCode));
      }
      final decoded = jsonDecode(text);
      if (decoded is! Map) {
        throw StudyApiException('接口返回格式不对');
      }
      return Map<String, dynamic>.from(decoded);
    } on StudyApiException {
      rethrow;
    } on SocketException {
      throw StudyApiException('连不上本地服务，请确认服务已启动');
    } on TimeoutException {
      throw StudyApiException('请求超时，请稍后再试');
    } on FormatException {
      throw StudyApiException('接口返回的内容无法解析');
    } on HttpException {
      throw StudyApiException('网络请求失败，请稍后再试');
    }
  }

  /// 从错误响应里取服务端写的说明。
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
      // 返回体不是 JSON 时用状态码兜底。
    }
    return '服务返回错误（$statusCode）';
  }
}
