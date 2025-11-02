import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../config/env.dart';
import '../utils/validators.dart';

class AuthRepository {
  final AuthService authService;
  final SharedPreferences prefs;

  AuthRepository({required this.authService, required this.prefs});

  Future<void> saveTokens(String accessToken, String? refreshToken) async {
    await prefs.setString('access_token', accessToken);
    if (refreshToken != null) {
      await prefs.setString('refresh_token', refreshToken);
    }
  }

  String? get accessToken => prefs.getString('access_token');

  Future<Map<String, dynamic>> login({required String phone, required String password}) async {
    // 开发环境：仅进行格式校验，返回本地模拟用户与令牌
    if (Env.isDev) {
      if (!isValidMainlandPhone(phone)) {
        throw AuthException(message: '手机号格式错误（需中国大陆11位）', code: 400);
      }
      if (!isValidPassword(password)) {
        throw AuthException(message: '密码需8-20位，且包含字母和数字', code: 400);
      }
      await saveTokens('dev_access_token', 'dev_refresh_token');
      return {
        'user_id': 1,
        'nickname': 'DevUser',
        'phone': phone,
        'role': 'developer',
      };
    }

    // 生产/其他环境：走真实接口
    final res = await authService.login(phone: phone, password: password);
    final data = res.data as Map<String, dynamic>?
        ?? {'code': res.statusCode ?? -1, 'message': res.statusMessage, 'data': null};
    if ((data['code'] ?? 500) == 200) {
      final payload = data['data'] as Map<String, dynamic>?;
      final access = payload?['access_token'] as String?;
      final refresh = payload?['refresh_token'] as String?;
      if (access != null) {
        await saveTokens(access, refresh);
      }
      return payload ?? {};
    }
    throw AuthException(message: data['message']?.toString() ?? '登录失败', code: data['code'] ?? 500);
  }

  Future<Map<String, dynamic>> register({required String phone, required String otp, String? password}) async {
    if (Env.isDev) {
      if (!isValidMainlandPhone(phone)) {
        throw AuthException(message: '手机号格式错误（需中国大陆11位）', code: 400);
      }
      if (!isValidOtp(otp)) {
        throw AuthException(message: '验证码需为6位数字', code: 400);
      }
      if (password != null && password.isNotEmpty && !isValidPassword(password)) {
        throw AuthException(message: '密码需8-20位，且包含字母和数字', code: 400);
      }
      await saveTokens('dev_access_token', 'dev_refresh_token');
      return {
        'user_id': 2,
        'nickname': 'DevNewUser',
        'phone': phone,
        'role': 'developer',
      };
    }

    final res = await authService.register(phone: phone, otp: otp, password: password);
    final data = res.data as Map<String, dynamic>?
        ?? {'code': res.statusCode ?? -1, 'message': res.statusMessage, 'data': null};
    if ((data['code'] ?? 500) == 200) {
      final payload = data['data'] as Map<String, dynamic>?;
      final access = payload?['access_token'] as String?;
      final refresh = payload?['refresh_token'] as String?;
      if (access != null) {
        await saveTokens(access, refresh);
      }
      return payload ?? {};
    }
    throw AuthException(message: data['message']?.toString() ?? '注册失败', code: data['code'] ?? 500);
  }

  Future<Map<String, dynamic>> profile() async {
    if (Env.isDev) {
      // 开发环境返回本地模拟资料
      return {
        'user_id': 1,
        'nickname': 'DevUser',
        'avatar': null,
        'bio': '开发环境本地用户',
      };
    }
    final res = await authService.profile();
    final data = res.data as Map<String, dynamic>?
        ?? {'code': res.statusCode ?? -1, 'message': res.statusMessage, 'data': null};
    if ((data['code'] ?? 500) == 200) {
      return (data['data'] as Map<String, dynamic>?) ?? {};
    }
    throw AuthException(message: data['message']?.toString() ?? '获取资料失败', code: data['code'] ?? 500);
  }
}

class AuthException implements Exception {
  final String message;
  final int code;
  AuthException({required this.message, required this.code});
  @override
  String toString() => 'AuthException(code=$code, message=$message)';
}