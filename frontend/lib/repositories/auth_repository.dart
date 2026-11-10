import 'package:hive_flutter/hive_flutter.dart';
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

  /// 获取当前访问令牌（统一从 UserSession 获取）
  String? get accessToken => userSession.accessToken;

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

    // 通过 UserSession 统一管理用户和令牌
    await userSession.setUser(user, prefs,
        accessToken: token, refreshToken: refresh);

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
    if (code != 10000 && code != 200 && !(code == 0 && res.statusCode == 200)) {
      final msg = (base['msg'] ?? body['message'] ?? '注册失败').toString();
      throw AuthException(message: msg, code: code);
    }

    final raw = (body['data'] as Map<String, dynamic>?) ?? body;
    final user = User.fromJson(raw);

    // 处理注册响应中可能包含的 token
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

    // 通过 UserSession 统一管理用户和令牌
    await userSession.setUser(user, prefs,
        accessToken: token, refreshToken: refresh);

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
    if (code != 10000 && code != 200 && !(code == 0 && res.statusCode == 200)) {
      final msg = (base['msg'] ?? body['message'] ?? '获取资料失败').toString();
      throw AuthException(message: msg, code: code);
    }
    final raw = (body['data'] as Map<String, dynamic>?) ?? body;
    final user = User.fromJson(raw);

    // 更新 UserSession 中的用户信息（不改变 token）
    if (userSession.userId == user.id) {
      userSession.updateUser(user);
    } else {
      await userSession.setUser(user, prefs);
    }

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
      // 后端暂无强制吊销接口时，失败也继续清本地（幂等）
      await authService.logout();
    } catch (_) {
      // ignore: 本地退出必须成功
    } finally {
      await userSession.clear(prefs);
      await prefs.remove('auth_user_id');
      try {
        if (Hive.isBoxOpen('user_box')) {
          await Hive.box('user_box').clear();
        }
      } catch (_) {}
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

  /// 把网关包装的技术文案收敛成可读提示
  static String friendlyMessage(String raw) {
    final s = raw.trim();
    if (s.contains('密码错误') || s.contains('password')) return '用户名或密码错误';
    if (s.contains('user not exist') || s.contains('用户不存在')) return '用户不存在';
    if (s.contains('验证码') || s.contains('code')) {
      if (s.contains('过期') || s.contains('expire')) return '验证码已过期，请重新获取';
      if (s.contains('错误') || s.contains('invalid')) return '验证码错误';
    }
    if (s.contains('已存在') || s.contains('already')) return '用户名或邮箱已被注册';
    if (s.contains('internal server error') || s.contains('remote or network')) {
      // 尽量从尾部抽取业务中文
      final m = RegExp(r'[\u4e00-\u9fff]{2,}').allMatches(s).map((e) => e.group(0)!).toList();
      if (m.isNotEmpty) return m.last;
      return '服务暂时不可用，请稍后重试';
    }
    if (s.startsWith('AuthException')) {
      final m = RegExp(r'message=(.+)\)$').firstMatch(s);
      if (m != null) return friendlyMessage(m.group(1)!);
    }
    return s.isEmpty ? '操作失败，请稍后重试' : s;
  }

  @override
  String toString() => friendlyMessage(message);
}
