import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import '../config/env.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class ApiClient {
  final Dio _dio;
  final SharedPreferences prefs;
  final Logger _logger = Logger();
  bool _refreshing = false;

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
          options.headers['Access-Token'] = token;
        }
        final refresh = prefs.getString('refresh_token');
        if (refresh != null && refresh.isNotEmpty) {
          options.headers['Refresh-Token'] = refresh;
        }
        if (Env.isDev || kDebugMode) {
          try {
            final uri = options.uri.toString();
            final qp = jsonEncode(options.queryParameters);
            String bodyDesc = '';
            final data = options.data;
            if (data is FormData) {
              bodyDesc = 'FormData(fields=${data.fields.length}, files=${data.files.length})';
            } else if (data != null) {
              bodyDesc = jsonEncode(data);
            }
            _logger.i('HTTP ${options.method} $uri query=$qp body=$bodyDesc');
          } catch (_) {}
        }
        handler.next(options);
      },
      onResponse: (response, handler) async {
        // 业务层返回 code=30000 表示无效令牌，尝试刷新并重试
        try {
          final data = response.data;
          int? bizCode;
          if (data is Map<String, dynamic>) {
            final base = data['base'];
            final top = data['code'];
            bizCode = base is Map<String, dynamic> && base['code'] is int ? base['code'] as int : (top is int ? top : int.tryParse('$top'));
          }
          if (bizCode == 30000 && !_refreshing) {
            final retried = await _tryRefreshAndRetry(response.requestOptions);
            if (retried != null) {
              return handler.resolve(retried);
            }
          }
        } catch (_) {}
        if (Env.isDev || kDebugMode) {
          try {
            final uri = response.requestOptions.uri.toString();
            final status = response.statusCode;
            String body = '';
            try {
              body = jsonEncode(response.data);
            } catch (_) {
              body = '${response.data}';
            }
            if (body.length > 600) body = body.substring(0, 600) + '...';
            _logger.i('HTTP $status $uri resp=$body');
          } catch (_) {}
        }
        handler.next(response);
      },
      onError: (DioException e, handler) async {
        _logger.e('API Error', error: e, stackTrace: e.stackTrace);
        if (Env.isDev || kDebugMode) {
          try {
            final uri = e.requestOptions.uri.toString();
            final status = e.response?.statusCode;
            _logger.w('HTTP ERROR status=$status url=$uri');
          } catch (_) {}
        }
        if ((e.response?.statusCode == 401 || e.response?.statusCode == 403) && !_refreshing) {
          final retried = await _tryRefreshAndRetry(e.requestOptions);
          if (retried != null) {
            return handler.resolve(retried);
          }
        }
        handler.next(e);
      },
    ));
    if (Env.isDev || kDebugMode) {
      _dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
    }
  }

  Future<Response<dynamic>?> _tryRefreshAndRetry(RequestOptions failed) async {
    _refreshing = true;
    try {
      _logger.i('Attempting token refresh for ${failed.uri}');
      final userId = prefs.getString('auth_user_id');
      final refresh = prefs.getString('refresh_token');
      if (userId == null || refresh == null) {
        _logger.w('Token refresh skipped: missing user_id or refresh_token');
        prefs.remove('access_token');
        prefs.remove('refresh_token');
        return null;
      }
      final refreshDio = Dio(BaseOptions(baseUrl: _dio.options.baseUrl));
      final resp = await refreshDio.post('/user/token/refresh', queryParameters: {
        'user_id': userId,
        'refresh_token': refresh,
      });
      final data = resp.data as Map<String, dynamic>? ?? {};
      final raw = (data['data'] as Map<String, dynamic>?) ?? data;
      final newToken = (raw['token'] ?? raw['access_token'])?.toString();
      final newRefresh = (raw['refresh_token'] ?? raw['refreshToken'])?.toString();
      if (newToken == null || newToken.isEmpty) {
        _logger.w('Token refresh failed: empty token');
        return null;
      }
      await prefs.setString('access_token', newToken);
      if (newRefresh != null && newRefresh.isNotEmpty) {
        await prefs.setString('refresh_token', newRefresh);
      }
      // 更新原请求的 Authorization 并重试
      failed.headers['Authorization'] = 'Bearer $newToken';
      return await _dio.fetch(failed);
    } catch (err, st) {
      _logger.e('Token refresh error', error: err, stackTrace: st);
      prefs.remove('access_token');
      prefs.remove('refresh_token');
      return null;
    } finally {
      _refreshing = false;
    }
  }

  Dio get dio => _dio;
}
