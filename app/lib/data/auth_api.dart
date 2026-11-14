import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 登录接口错误。
class AuthApiException implements Exception {
  AuthApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 登录后的用户信息。
class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.role,
    required this.mustChangePassword,
  });

  final String id;
  final String username;

  /// `user` 普通用户（只读）；`admin` 管理员（可编辑一切）。
  final String role;
  final bool mustChangePassword;

  bool get isAdmin => role == 'admin';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'username': username,
        'role': role,
        'mustChangePassword': mustChangePassword,
      };

  static AuthUser fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        username: json['username'] as String,
        role: json['role'] as String? ?? 'user',
        mustChangePassword: json['mustChangePassword'] as bool? ?? false,
      );
}

/// 九境三阶的当前境界。
class AuthDegree {
  const AuthDegree({required this.realm, required this.realmLabel, required this.stage});

  final String realm;
  final String realmLabel;
  final String stage;

  static AuthDegree none() => const AuthDegree(realm: 'none', realmLabel: '未入门', stage: 'early');

  static AuthDegree fromJson(Map<String, dynamic> json) => AuthDegree(
        realm: json['realm'] as String? ?? 'none',
        realmLabel: json['realmLabel'] as String? ?? '未入门',
        stage: json['stage'] as String? ?? 'early',
      );
}

/// 学位申请记录。
class AuthDegreeApplication {
  const AuthDegreeApplication({
    required this.id,
    required this.targetRealm,
    required this.targetRealmLabel,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String targetRealm;
  final String targetRealmLabel;
  final String status;
  final String createdAt;

  static AuthDegreeApplication fromJson(Map<String, dynamic> json) => AuthDegreeApplication(
        id: json['id'] as String,
        targetRealm: json['targetRealm'] as String? ?? '',
        targetRealmLabel: json['targetRealmLabel'] as String? ?? '',
        status: json['status'] as String? ?? 'pending',
        createdAt: json['createdAt'] as String? ?? '',
      );
}

/// 九境三阶的境界可选值（按从低到高）。
const List<String> kDegreeRealms = [
  'shi',
  'gou',
  'tong',
  'bian',
  'chuang',
  'li',
  'hua',
  'zong',
  'dao',
];

const Map<String, String> kDegreeRealmLabels = {
  'shi': '识境',
  'gou': '构境',
  'tong': '通境',
  'bian': '辨境',
  'chuang': '创境',
  'li': '立境',
  'hua': '化境',
  'zong': '宗境',
  'dao': '道境',
};

/// 登录成功的结果：会话 token + 用户信息。
class AuthLoginResult {
  const AuthLoginResult({required this.token, required this.user});

  final String token;
  final AuthUser user;
}

/// 账号接口：登录、退出、改密、学位。
abstract class AuthApi {
  Future<AuthLoginResult> login(String username, String password);
  Future<void> logout(String token);
  Future<AuthUser> changePassword({
    required String token,
    required String oldPassword,
    required String newPassword,
  });

  /// 当前境界；未设过时返回未入门。
  Future<AuthDegree> fetchDegree(String token);

  /// 提交学位申请（九境三阶，管理员审核通过后提升境界）。
  Future<AuthDegreeApplication> applyForDegree({
    required String token,
    required String targetRealm,
    Map<String, Object?> evidence = const {},
  });
}

/// 默认实现：访问本地服务，地址与 StudyApi 一致。
class HttpAuthApi implements AuthApi {
  HttpAuthApi({String? baseUrl, HttpClient? client})
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
  Future<AuthLoginResult> login(String username, String password) async {
    final map = await _request('POST', '/api/auth/login', body: {
      'username': username,
      'password': password,
    });
    final token = map['token'];
    final user = map['user'];
    if (token is! String || user is! Map) {
      throw AuthApiException('登录返回格式不对');
    }
    return AuthLoginResult(
      token: token,
      user: AuthUser.fromJson(Map<String, dynamic>.from(user)),
    );
  }

  @override
  Future<void> logout(String token) async {
    await _request('POST', '/api/auth/logout', token: token);
  }

  @override
  Future<AuthUser> changePassword({
    required String token,
    required String oldPassword,
    required String newPassword,
  }) async {
    final map = await _request('POST', '/api/auth/password',
        token: token, body: {'oldPassword': oldPassword, 'newPassword': newPassword});
    final user = map['user'];
    if (user is! Map) {
      throw AuthApiException('改密返回格式不对');
    }
    return AuthUser.fromJson(Map<String, dynamic>.from(user));
  }

  @override
  Future<AuthDegree> fetchDegree(String token) async {
    final map = await _request('GET', '/api/degree', token: token);
    final degree = map['degree'];
    if (degree is! Map) {
      return AuthDegree.none();
    }
    return AuthDegree.fromJson(Map<String, dynamic>.from(degree));
  }

  @override
  Future<AuthDegreeApplication> applyForDegree({
    required String token,
    required String targetRealm,
    Map<String, Object?> evidence = const {},
  }) async {
    final map = await _request('POST', '/api/degree/applications',
        token: token, body: {'targetRealm': targetRealm, 'evidence': evidence});
    final application = map['application'];
    if (application is! Map) {
      throw AuthApiException('申请返回格式不对');
    }
    return AuthDegreeApplication.fromJson(Map<String, dynamic>.from(application));
  }

  Future<Map<String, dynamic>> _request(String method, String path,
      {String? token, Object? body}) async {
    try {
      final uri = Uri.parse('$_baseUrl$path');
      final request = await _client.openUrl(method, uri).timeout(_timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (token != null) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close().timeout(_timeout);
      final text =
          await response.transform(utf8.decoder).join().timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AuthApiException(_errorMessage(text, response.statusCode));
      }
      final decoded = jsonDecode(text);
      if (decoded is! Map) {
        throw AuthApiException('接口返回格式不对');
      }
      return Map<String, dynamic>.from(decoded);
    } on AuthApiException {
      rethrow;
    } on SocketException {
      throw AuthApiException('连不上本地服务，请确认服务已启动');
    } on TimeoutException {
      throw AuthApiException('请求超时，请稍后再试');
    } on FormatException {
      throw AuthApiException('接口返回的内容无法解析');
    } on HttpException {
      throw AuthApiException('网络请求失败，请稍后再试');
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
      // 返回体不是 JSON 时用状态码兜底。
    }
    return '服务返回错误（$statusCode）';
  }
}
