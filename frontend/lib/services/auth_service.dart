import 'package:dio/dio.dart';
import '../services/api_client.dart';
import '../config/env.dart';

class AuthService {
  final ApiClient client;
  AuthService(this.client);

  Future<Response<dynamic>> login({required String phone, required String password}) {
    if (Env.isDev) {
      return Future.value(Response(
        requestOptions: RequestOptions(path: '/api/v1/auth/login'),
        data: {
          'code': 200,
          'message': 'success',
          'data': {
            'access_token': 'dev_access_token',
            'refresh_token': 'dev_refresh_token',
          },
        },
        statusCode: 200,
      ));
    }
    return client.dio.post('/api/v1/auth/login', data: {
      'phone': phone,
      'password': password,
    });
  }

  Future<Response<dynamic>> register({required String phone, required String otp, String? password}) {
    if (Env.isDev) {
      return Future.value(Response(
        requestOptions: RequestOptions(path: '/api/v1/auth/register'),
        data: {
          'code': 200,
          'message': 'success',
          'data': {
            'access_token': 'dev_access_token',
            'refresh_token': 'dev_refresh_token',
          },
        },
        statusCode: 200,
      ));
    }
    return client.dio.post('/api/v1/auth/register', data: {
      'phone': phone,
      'otp': otp,
      if (password != null) 'password': password,
    });
  }

  Future<Response<dynamic>> profile() {
    if (Env.isDev) {
      return Future.value(Response(
        requestOptions: RequestOptions(path: '/api/v1/user/profile'),
        data: {
          'code': 200,
          'message': 'success',
          'data': {
            'user_id': 1,
            'nickname': 'DevUser',
            'avatar': null,
            'bio': '开发环境本地用户',
          },
        },
        statusCode: 200,
      ));
    }
    return client.dio.get('/api/v1/user/profile');
  }
}