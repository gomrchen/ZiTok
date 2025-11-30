import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_client.dart';
import '../config/env.dart';

/// 认证服务（登录、注册、资料）
class AuthService {
  final ApiClient client;
  late final ApiClient _verificationClient;

  AuthService(this.client, {required SharedPreferences prefs}) {
    // 创建专门用于验证码请求的 ApiClient 实例，使用不同的 baseUrl
    _verificationClient = ApiClient(
      baseUrl: Env.verificationBaseUrl,
      prefs: prefs,
    );
  }

  /// 登录：用户名 + 密码
  Future<Response<dynamic>> login({
    required String username,
    required String password,
  }) {
    return client.dio.post(
      '/user/login',
      data: {'username': username, 'password': password},
    );
  }

  /// 注册：用户名 + 邮箱 + 密码 + 验证码
  Future<Response<dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String verificationCode,
  }) {
    return client.dio.post(
      '/user/register',
      data: {
        'username': username,
        'email': email,
        'password': password,
        'code': verificationCode,
      },
    );
  }

  /// 当前用户信息
  Future<Response<dynamic>> profile() {
    return client.dio.get('/user/info');
  }

  /// 修改密码
  Future<Response<dynamic>> changePassword({
    required String code,
    required String newPassword,
    required String email,
  }) {
    return client.dio.post(
      '/user/password',
      data: {'email': email, 'code': code, 'newPwd': newPassword},
    );
  }

  // 发送验证码 - 使用专门的端口号
  Future<Response<dynamic>> sendVerificationCode({required String email}) {
    // 使用专门的验证码服务客户端
    return _verificationClient.dio.post(
      '/send_code',
      data: {'email': email},
    );
  }

  /// 登出
  Future<Response<dynamic>> logout() {
    return client.dio.post('/user/logout');
  }

  /// 刷新令牌
  ///
  /// 使用 refresh_token 换取新的 access_token
  /// 注意：这里使用独立的 Dio 实例，避免被拦截器干扰
  Future<Response<dynamic>> refreshToken({
    required String userId,
    required String refreshToken,
  }) {
    // 使用独立的 Dio 实例，避免触发拦截器的token刷新逻辑
    final refreshDio = Dio(BaseOptions(
      baseUrl: client.dio.options.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
    return refreshDio.post(
      '/user/token/refresh',
      queryParameters: {
        'user_id': userId,
        'refresh_token': refreshToken,
      },
    );
  }
}
