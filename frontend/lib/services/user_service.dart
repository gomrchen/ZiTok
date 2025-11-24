import 'package:dio/dio.dart';
import '../models/user_models.dart';

/// 用户接口服务（对接真实 API）
class UserService {
  final Dio dio;
  UserService(this.dio);

  /// 注册
  Future<Response> register({required String username, required String email, required String password}) {
    return dio.post('/user/register', data: {
      'username': username,
      'email': email,
      'password': password,
    });
  }

  /// 登录
  Future<Response> login({required String username, required String password}) {
    return dio.post('/user/login', data: {
      'username': username,
      'password': password,
    });
  }

  /// 用户信息
  Future<Response> info({String? userId}) {
    return dio.get('/user/info', queryParameters: {
      if (userId != null) 'user_id': userId,
    });
  }

  /// 上传头像（multipart/form-data）
  Future<Response> uploadAvatar({required String userId, required MultipartFile avatarData}) {
    final form = FormData.fromMap({
      'avatar_data': avatarData,
      'user_id': userId,
    });
    return dio.post('/user/avatar', data: form);
  }

  /// 上传资料背景图（multipart/form-data）
  Future<Response> uploadProfileBackground({required String userId, required MultipartFile backgroundData}) {
    final form = FormData.fromMap({
      'background_data': backgroundData,
      'user_id': userId,
    });
    return dio.post('/user/profile/background', data: form);
  }

  /// 更新基本资料
  Future<Response> updateInfo(UserUpdateRequest req) {
    return dio.put('/user/info', queryParameters: req.toQuery());
  }

  /// 修改密码
  Future<Response> updatePassword({required String email, required String oldPassword, required String newPassword}) {
    return dio.put('/user/password', data: {
      'email': email,
      'old_password': oldPassword,
      'new_password': newPassword,
    });
  }
}
