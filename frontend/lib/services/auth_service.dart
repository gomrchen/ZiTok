import 'package:dio/dio.dart';
import '../services/api_client.dart';

/// 认证服务（登录、注册、资料）
class AuthService {
  final ApiClient client;
  AuthService(this.client);

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
        'verification_code': verificationCode,
      },
    );
  }

  /// 当前用户信息
  Future<Response<dynamic>> profile() {
    return client.dio.get('/user/info');
  }

  /// 修改密码
  Future<Response<dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
    required String email,
  }) {
    return client.dio.post(
      '/user/password',
      data: {'email': email, 'code': oldPassword, 'new_password': newPassword},
    );
  }

  /// 登出
  Future<Response<dynamic>> logout() {
    return client.dio.post('/user/logout');
  }
}
