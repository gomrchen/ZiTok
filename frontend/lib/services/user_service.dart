import 'package:dio/dio.dart';

class UserService {
  final Dio dio;
  UserService(this.dio);

  Future<Response> register({required String userName, required String email, required String password}) {
    return dio.post('/api/user/register', data: {
      'user_name': userName,
      'email': email,
      'password': password,
    });
  }

  Future<Response> login({required String email, required String password}) {
    return dio.post('/api/user/login', data: {
      'email': email,
      'password': password,
    });
  }

  Future<Response> info({required String userId}) {
    return dio.get('/user/info', queryParameters: {
      'user_id': userId,
    });
  }


  Future<Response> downloadAvatar({required int uid}) {
    return dio.get('/api/user/auth/download-avatar', queryParameters: {'uid': uid});
  }

  Future<Response> uploadAvatar({required int uid, required MultipartFile avatar, required String fileName}) {
    final form = FormData.fromMap({'uid': uid, 'avatar': avatar, 'file_name': fileName});
    return dio.post('/api/user/auth/upload-avatar', data: form);
  }

  Future<Response> uploadBackdrop({required int uid, required MultipartFile cover, required String fileName}) {
    final form = FormData.fromMap({'uid': uid, 'cover': cover, 'file_name': fileName});
    return dio.post('/api/user/auth/upload-cover', data: form);
  }

  Future<Response> totpQrcode({required int uid, required String userName}) {
    return dio.get('/api/user/auth/totp-qrcode', queryParameters: {
      'uid': uid,
      'user_name': userName,
    });
  }

  Future<Response> enableTotp({required int uid, required String code}) {
    return dio.post('/api/user/auth/enable-totp', data: {
      'uid': uid,
      'code': code,
    });
  }
}
