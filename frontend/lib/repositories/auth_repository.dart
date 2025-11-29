import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/user_session.dart';
import '../models/user_models.dart';

/// 认证仓库：调用服务并处理持久化与类型转换
class AuthRepository {
  final AuthService authService;
  final SharedPreferences prefs;
  final UserSession userSession;

  AuthRepository({
    required this.authService,
    required this.prefs,
    required this.userSession,
  });

  String? get accessToken => prefs.getString('access_token');

  /// 登录并返回用户
  Future<User> login({
    required String username,
    required String password,
  }) async {
    final res =
        await authService.login(username: username, password: password);
    final body = res.data as Map<String, dynamic>? ?? {};
    final base = body['base'] as Map<String, dynamic>? ?? {};
    final topCode = body['code'];
    final code = (base['code'] is int
        ? base['code'] as int
        : topCode is int
            ? topCode
            : int.tryParse('$topCode') ?? 0);
    if (code != 10000 && code != 200 && !(code == 0 && res.statusCode == 200)) {
      final msg = (base['msg'] ?? body['message'] ?? '登录失败').toString();
      throw AuthException(message: msg, code: code);
    }
    final raw = (body['data'] as Map<String, dynamic>?) ?? body;
    User user = User.fromJson(raw);

    // 持久化 token
    String? token = (raw['token'] ?? raw['access_token'])?.toString();
    if (token == null || token.isEmpty) {
      final headerAuth = res.headers['authorization']?.first;
      if (headerAuth != null &&
          headerAuth.toLowerCase().startsWith('bearer ')) {
        token = headerAuth.substring(7);
      }
    }
    final refresh =
        (raw['refresh_token'] ?? raw['refreshToken'])?.toString();
    if (token != null && token.isNotEmpty) {
      await prefs.setString('access_token', token);
    }
    if (refresh != null && refresh.isNotEmpty) {
      await prefs.setString('refresh_token', refresh);
    }

    // 通过 UserSession 统一管理用户 ID
    await userSession.setUser(user, prefs);

    // 兼容旧代码：同时保存到旧的 key
    await prefs.setString('auth_user_id', user.id);

    return user;
  }

  /// 注册并返回用户
  Future<User> register({
    required String username,
    required String email,
    required String password,
    required String verificationCode,
  }) async {
    final res = await authService.register(
      username: username,
      email: email,
      password: password,
      verificationCode: verificationCode,
    );
    final body = res.data as Map<String, dynamic>? ?? {};
    final base = body['base'] as Map<String, dynamic>? ?? {};
    final topCode = body['code'];
    final code = (base['code'] is int
        ? base['code'] as int
        : topCode is int
            ? topCode
            : int.tryParse('$topCode') ?? 0);
    if (code == 0 && (res.statusCode == 200)) {
      final raw = (body['data'] as Map<String, dynamic>?) ?? body;
      final user = User.fromJson(raw);
      await userSession.setUser(user, prefs);
      await prefs.setString('auth_user_id', user.id);
      return user;
    }
    if (code != 10000 && code != 200) {
      final msg = (base['msg'] ?? body['message'] ?? '注册失败').toString();
      throw AuthException(message: msg, code: code);
    }
    final raw = (body['data'] as Map<String, dynamic>?) ?? body;
    final user = User.fromJson(raw);
    await userSession.setUser(user, prefs);
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
            : int.tryParse('$topCode') ?? 0);
    if (code == 0 && (res.statusCode == 200)) {
      final raw = (body['data'] as Map<String, dynamic>?) ?? body;
      final user = User.fromJson(raw);
      await userSession.setUser(user, prefs);
      await prefs.setString('auth_user_id', user.id);
      return user;
    }
    if (code != 10000 && code != 200) {
      final msg = (base['msg'] ?? body['message'] ?? '获取资料失败').toString();
      throw AuthException(message: msg, code: code);
    }
    final raw = (body['data'] as Map<String, dynamic>?) ?? body;
    final user = User.fromJson(raw);
    await userSession.setUser(user, prefs);
    await prefs.setString('auth_user_id', user.id);
    return user;
  }

  /// 修改密码
  Future<void> changePassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final res = await authService.changePassword(
      email: email,
      code: code,
      newPassword: newPassword,
    );
    final body = res.data as Map<String, dynamic>? ?? {};
    final base = body['base'] as Map<String, dynamic>? ?? {};
    final topCode = body['code'];
    final resCode = (base['code'] is int
        ? base['code'] as int
        : topCode is int
            ? topCode
            : int.tryParse('$topCode') ?? 0);
    if (resCode == 0 && (res.statusCode == 200)) {
      return;
    }
    if (resCode != 10000 && resCode != 200) {
      final msg = (base['msg'] ?? body['message'] ?? '修改密码失败').toString();
      throw AuthException(message: msg, code: resCode);
    }
  }

  /// 登出，清除本地认证信息
  Future<void> logout() async {
    try {
      await authService.logout();
    } catch (_) {
      // 即使后端接口调用失败，也继续清除本地数据
    } finally {
      // 通过 UserSession 清除用户信息
      await userSession.clear(prefs);

      // 清除本地存储的认证信息
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
      await prefs.remove('auth_user_id');
    }
  }

  /// 发送验证码到邮箱
  Future<void> sendVerificationCode({required String email}) async {
    final res = await authService.sendVerificationCode(email: email);
    final body = res.data as Map<String, dynamic>? ?? {};
    final base = body['base'] as Map<String, dynamic>? ?? {};
    final topCode = body['code'];
    final code = (base['code'] is int
        ? base['code'] as int
        : topCode is int
            ? topCode
            : int.tryParse('$topCode') ?? 0);
    if (code != 10000 && code != 200 && !(code == 0 && res.statusCode == 200)) {
      final msg = (base['msg'] ?? body['message'] ?? '发送验证码失败').toString();
      throw AuthException(message: msg, code: code);
    }
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
