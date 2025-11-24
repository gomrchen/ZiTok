import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../models/user_models.dart';

/// 认证仓库：调用服务并处理持久化与类型转换
class AuthRepository {
  final AuthService authService;
  final SharedPreferences prefs;

  AuthRepository({required this.authService, required this.prefs});

  String? get accessToken => prefs.getString('access_token');

  /// 登录并返回用户
  Future<User> login({required String username, required String password}) async {
    final res = await authService.login(username: username, password: password);
    final body = res.data as Map<String, dynamic>? ?? {};
    final base = body['base'] as Map<String, dynamic>? ?? {};
    final topCode = body['code'];
    final code = (base['code'] is int
        ? base['code'] as int
        : topCode is int
            ? topCode
            : int.tryParse('${topCode}') ?? 0);
    if (code != 10000 && code != 200 && !(code == 0 && res.statusCode == 200)) {
      final msg = (base['msg'] ?? body['message'] ?? '登录失败').toString();
      throw AuthException(message: msg, code: code);
    }
    final raw = (body['data'] as Map<String, dynamic>?) ?? body;
    final user = User.fromJson(raw);
    // 持久化 token 与用户ID
    String? token = (raw['token'] ?? raw['access_token'])?.toString();
    // 兼容后端将 token 放在响应头的情况
    if (token == null || token.isEmpty) {
      final headerAuth = res.headers['authorization']?.first;
      if (headerAuth != null && headerAuth.toLowerCase().startsWith('bearer ')) {
        token = headerAuth.substring(7);
      }
    }
    final refresh = (raw['refresh_token'] ?? raw['refreshToken'])?.toString();
    final uid = (raw['user_id'] ?? raw['uid'] ?? user.id).toString();
    if (token != null && token.isNotEmpty) await prefs.setString('access_token', token);
    if (refresh != null && refresh.isNotEmpty) await prefs.setString('refresh_token', refresh);
    await prefs.setString('auth_user_id', uid);
    return user;
  }

  /// 注册并返回用户
  Future<User> register({required String username, required String email, required String password}) async {
    final res = await authService.register(username: username, email: email, password: password);
    final body = res.data as Map<String, dynamic>? ?? {};
    final base = body['base'] as Map<String, dynamic>? ?? {};
    final topCode = body['code'];
    final code = (base['code'] is int
        ? base['code'] as int
        : topCode is int
            ? topCode
            : int.tryParse('${topCode}') ?? 0);
    if (code == 0 && (res.statusCode == 200)) {
      final raw = (body['data'] as Map<String, dynamic>?) ?? body;
      final user = User.fromJson(raw);
      await prefs.setString('auth_user_id', user.id);
      return user;
    }
    if (code != 10000 && code != 200) {
      final msg = (base['msg'] ?? body['message'] ?? '注册失败').toString();
      throw AuthException(message: msg, code: code);
    }
    final raw = (body['data'] as Map<String, dynamic>?) ?? body;
    final user = User.fromJson(raw);
    await prefs.setString('auth_user_id', user.id);
    return user;
  }

  /// 拉取当前用户信息
  Future<User> profile() async {
    final res = await authService.profile();
    final body = res.data as Map<String, dynamic>? ?? {};
    final base = body['base'] as Map<String, dynamic>? ?? {};
    final topCode = body['code'];
    final code = (base['code'] is int
        ? base['code'] as int
        : topCode is int
            ? topCode
            : int.tryParse('${topCode}') ?? 0);
    if (code == 0 && (res.statusCode == 200)) {
      final raw = (body['data'] as Map<String, dynamic>?) ?? body;
      final user = User.fromJson(raw);
      await prefs.setString('auth_user_id', user.id);
      return user;
    }
    if (code != 10000 && code != 200) {
      final msg = (base['msg'] ?? body['message'] ?? '获取资料失败').toString();
      throw AuthException(message: msg, code: code);
    }
    final raw = (body['data'] as Map<String, dynamic>?) ?? body;
    final user = User.fromJson(raw);
    await prefs.setString('auth_user_id', user.id);
    return user;
  }
}

/// 认证异常类型
class AuthException implements Exception {
  final String message;
  final int code;
  AuthException({required this.message, required this.code});
  @override
  String toString() => 'AuthException(code=$code, message=$message)';
}
