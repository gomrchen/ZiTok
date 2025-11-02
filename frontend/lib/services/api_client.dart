import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import '../config/env.dart';

class ApiClient {
  final Dio _dio;
  final SharedPreferences prefs;
  final Logger _logger = Logger();

  ApiClient({required String baseUrl, required this.prefs})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 20),
          headers: {
            'User-Agent': 'ZitokApp/1.0',
            'Accept-Language': 'zh-CN',
          },
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = prefs.getString('access_token');
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        // 开发环境下对部分接口进行本地短路，避免真实网络访问
        if (Env.isDev) {
          final path = options.path;
          if (path.startsWith('/api/v1/auth/login')) {
            return handler.resolve(Response(
              requestOptions: options,
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
          if (path.startsWith('/api/v1/auth/register')) {
            return handler.resolve(Response(
              requestOptions: options,
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
          if (path.startsWith('/api/v1/user/profile')) {
            return handler.resolve(Response(
              requestOptions: options,
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
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        handler.next(response);
      },
      onError: (DioException e, handler) {
        _logger.e('API Error', error: e, stackTrace: e.stackTrace);
        handler.next(e);
      },
    ));
  }

  Dio get dio => _dio;
}