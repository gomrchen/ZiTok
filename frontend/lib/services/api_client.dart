import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import '../config/env.dart';
import 'mock/mock_video_service.dart';

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
          // 对齐后端网关 REST 路由（/api/*）
          if (path.startsWith('/api/user/login')) {
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
          if (path.startsWith('/api/user/register')) {
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
          if (path.startsWith('/api/user/auth/info')) {
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
          // 视频相关接口在开发环境走本地 mock
          if (path.startsWith('/api/video/search')) {
            final body = options.data is Map<String, dynamic> ? options.data as Map<String, dynamic> : {};
            final content = body['content']?.toString();
            final pages = body['pages'] is int ? body['pages'] as int : int.tryParse('${body['pages']}') ?? 1;
            final size = body['size'] is int ? body['size'] as int : int.tryParse('${body['size']}') ?? 20;
            final data = MockVideoApi.search(content: content, page: pages, size: size);
            // 顶层返回 items/count，以匹配 Repository 读取逻辑
            return handler.resolve(Response(requestOptions: options, data: data, statusCode: 200));
          }
          if (path.startsWith('/api/video/popular')) {
            final data = MockVideoApi.popular(page: 1, size: 20);
            return handler.resolve(Response(requestOptions: options, data: data, statusCode: 200));
          }
          if (path.startsWith('/api/video/feed')) {
            final data = MockVideoApi.feed(page: 1, size: 20);
            return handler.resolve(Response(requestOptions: options, data: data, statusCode: 200));
          }
          if (path.startsWith('/api/video/auth/list')) {
            // 关注列表（用户发布的视频），开发环境返回模拟数据
            final data = MockVideoApi.feed(page: 1, size: 20);
            return handler.resolve(Response(requestOptions: options, data: data, statusCode: 200));
          }
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        handler.next(response);
      },
      onError: (DioException e, handler) {
        _logger.e('API Error', error: e, stackTrace: e.stackTrace);
        // 简单的认证失败处理：清除本地令牌，后续可扩展刷新逻辑
        if (e.response?.statusCode == 401) {
          prefs.remove('access_token');
          prefs.remove('refresh_token');
        }
        handler.next(e);
      },
    ));
  }

  Dio get dio => _dio;
}