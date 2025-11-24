import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import '../config/env.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// 统一网络客户端
///
/// - 注入鉴权头：`Authorization/Access-Token/Refresh-Token`
/// - 业务码与 HTTP 错误处理：`code=30000` 或 `401/403` 触发刷新重试
/// - 开发态日志：请求/响应精简输出
class ApiClient {
  final Dio _dio;
  final SharedPreferences prefs;
  final Logger _logger = Logger();
  bool _refreshing = false;

  ApiClient({required String baseUrl, required this.prefs})
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 20),
            sendTimeout: const Duration(seconds: 20),
            headers: {
              'User-Agent': 'ZitokApp/1.0',
              'Accept-Language': 'zh-CN',
            },
          ),
        ) {
    _setupInterceptors();
  }

  /// 是否输出调试日志
  bool get _shouldLog => Env.isDev || kDebugMode;

  /// 安装统一拦截器：请求头、日志、业务码与错误处理
  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          _injectAuthHeaders(options);
          if (_shouldLog) _logRequest(options);
          handler.next(options);
        },
        onResponse: (response, handler) async {
          final bizCode = _extractBizCode(response.data);
          if (bizCode == 30000 && !_refreshing) {
            final retried = await _refreshAndRetry(response.requestOptions);
            if (retried != null) return handler.resolve(retried);
          }
          if (_shouldLog) _logResponse(response);
          handler.next(response);
        },
        onError: (DioException e, handler) async {
          _logger.e('API Error', error: e, stackTrace: e.stackTrace);
          if (_shouldLog) {
            try {
              _logger.w('HTTP ERROR status=${e.response?.statusCode} url=${e.requestOptions.uri}');
            } catch (_) {}
          }
          final status = e.response?.statusCode;
          if ((status == 401 || status == 403) && !_refreshing) {
            final retried = await _refreshAndRetry(e.requestOptions);
            if (retried != null) return handler.resolve(retried);
          }
          handler.next(e);
        },
      ),
    );
    // 移除额外 LogInterceptor，避免与自定义日志重复
  }

  /// 注入鉴权头（若存在）
  void _injectAuthHeaders(RequestOptions options) {
    final token = prefs.getString('access_token');
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
      options.headers['Access-Token'] = token;
    }
    final refresh = prefs.getString('refresh_token');
    if (refresh != null && refresh.isNotEmpty) {
      options.headers['Refresh-Token'] = refresh;
    }
  }

  /// 解析业务码，兼容顶层 `code` 与 `base.code`
  int? _extractBizCode(dynamic data) {
    try {
      if (data is Map<String, dynamic>) {
        final base = data['base'];
        final top = data['code'];
        if (base is Map<String, dynamic> && base['code'] is int) return base['code'] as int;
        if (top is int) return top;
        return int.tryParse('$top');
      }
    } catch (_) {}
    return null;
  }

  /// 请求日志（开发态）
  void _logRequest(RequestOptions options) {
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

  /// 响应日志（开发态）
  void _logResponse(Response response) {
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

  /// 刷新令牌并重试失败请求
  Future<Response<dynamic>?> _refreshAndRetry(RequestOptions failed) async {
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
      final resp = await refreshDio.post(
        '/user/token/refresh',
        queryParameters: {
          'user_id': userId,
          'refresh_token': refresh,
        },
      );
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

  /// 暴露 Dio 实例给服务层使用
  Dio get dio => _dio;
}
