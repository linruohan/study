import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'auth_api.dart';

/// 登录会话入口：应用读这个单例判断身份与角色，测试可以替换。
abstract class AuthSessionStore {
  AuthUser? get user;
  String? get token;

  Future<void> login(String username, String password);
  Future<void> logout();
  Future<AuthUser> changePassword({
    required String oldPassword,
    required String newPassword,
  });

  /// 启动时从本地恢复上一次的登录态（token 过期由服务端 401 判断）。
  Future<void> restore();

  /// 当前境界；未登录或未查询过时返回未入门。
  AuthDegree get degree;

  /// 拉取当前境界。
  Future<AuthDegree> loadDegree();

  /// 提交学位申请，成功后返回申请记录。
  Future<AuthDegreeApplication> applyForDegree(String targetRealm);
}

/// 全局访问点：界面与数据层都从这里取当前登录态。
class AuthSession {
  AuthSession._();

  static AuthSessionStore? _instance;

  /// 测试或启动时注入实现；默认是本机文件实现。
  static AuthSessionStore get instance => _instance ??= FileAuthSession();

  static set instance(AuthSessionStore store) => _instance = store;

  static AuthUser? get user => instance.user;
  static String? get token => instance.token;
  static bool get isAdmin => instance.user?.isAdmin ?? false;
}

/// 本机文件登录会话：token 与用户信息存 auth_session.json。
class FileAuthSession extends ChangeNotifier implements AuthSessionStore {
  FileAuthSession({AuthApi? api, Directory? directory})
      : _api = api ?? HttpAuthApi(),
        _directory = directory;

  final AuthApi _api;
  final Directory? _directory;

  AuthUser? _user;
  String? _token;
  AuthDegree _degree = AuthDegree.none();
  bool _restored = false;

  @override
  AuthUser? get user => _user;

  @override
  String? get token => _token;

  @override
  AuthDegree get degree => _degree;

  @override
  Future<void> restore() async {
    if (_restored) {
      return;
    }
    _restored = true;
    try {
      final directory = _directory ?? await getApplicationDocumentsDirectory();
      final file = File('${directory.path}${Platform.pathSeparator}auth_session.json');
      if (!await file.exists()) {
        return;
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        return;
      }
      final token = decoded['token'];
      final user = decoded['user'];
      if (token is String && user is Map) {
        _token = token;
        _user = AuthUser.fromJson(Map<String, dynamic>.from(user));
      }
    } catch (_) {
      // 坏文件当作未登录处理。
    }
  }

  @override
  Future<void> login(String username, String password) async {
    final result = await _api.login(username, password);
    _token = result.token;
    _user = result.user;
    _degree = AuthDegree.none();
    await _persist();
    notifyListeners();
    // 登录后顺带取当前境界；失败不阻塞登录。
    try {
      await loadDegree();
    } catch (_) {}
  }

  @override
  Future<void> logout() async {
    final token = _token;
    _token = null;
    _user = null;
    _degree = AuthDegree.none();
    await _persist();
    notifyListeners();
    if (token != null) {
      try {
        await _api.logout(token);
      } catch (_) {
        // 会话已本地清除即可，远端过期自然失效。
      }
    }
  }

  @override
  Future<AuthUser> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final token = _token;
    if (token == null) {
      throw AuthApiException('还没有登录');
    }
    final user = await _api.changePassword(
      token: token,
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
    _user = user;
    await _persist();
    notifyListeners();
    return user;
  }

  @override
  Future<AuthDegree> loadDegree() async {
    final token = _token;
    if (token == null) {
      return _degree = AuthDegree.none();
    }
    try {
      _degree = await _api.fetchDegree(token);
    } on AuthApiException catch (error) {
      // 会话过期等情况：保持未入门，界面可重新登录。
      if ('$error'.contains('401')) {
        _degree = AuthDegree.none();
      }
      rethrow;
    }
    notifyListeners();
    return _degree;
  }

  @override
  Future<AuthDegreeApplication> applyForDegree(String targetRealm) async {
    final token = _token;
    if (token == null) {
      throw AuthApiException('还没有登录');
    }
    // 证据链先带学习广度/深度的自述占位，服务端管理员审核时人工复核。
    final application = await _api.applyForDegree(
      token: token,
      targetRealm: targetRealm,
      evidence: {
        'source': 'client_account_dialog',
        'note': '用户在账号弹窗自行提交，证据链由管理员复核学习广度与深度。',
      },
    );
    return application;
  }

  Future<void> _persist() async {
    try {
      final directory = _directory ?? await getApplicationDocumentsDirectory();
      final file = File('${directory.path}${Platform.pathSeparator}auth_session.json');
      if (_token == null || _user == null) {
        if (await file.exists()) {
          await file.delete();
        }
        return;
      }
      await file.writeAsString(
        jsonEncode({'token': _token, 'user': _user!.toJson()}),
        flush: true,
      );
    } catch (_) {
      // 保存失败不阻塞登录流程；下次登录会重写。
    }
  }
}
