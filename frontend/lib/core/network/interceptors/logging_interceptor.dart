/*
 * 文件版本号: 1.0.0
 * 文件功能说明: 网络请求日志拦截器，记录HTTP请求和响应的详细信息，便于开发调试和问题排查
 * 当前已知问题:
 *   - 生产环境下可能泄露敏感信息
 *   - 大量日志可能影响性能
 *   - 缺少日志级别控制和过滤机制
 * 修改需求说明:
 *   - 添加环境检测，生产环境下关闭或简化日志
 *   - 实现敏感信息过滤，如密码、Token等
 *   - 添加日志级别配置，支持不同详细程度的日志
 *   - 优化日志格式，提高可读性
 */

import 'package:dio/dio.dart';
import '../../utils/logger.dart';

/// 日志拦截器
/// 记录所有网络请求和响应的详细信息
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    AppLogger.info('🚀 请求开始');
    AppLogger.info('方法: ${options.method}');
    AppLogger.info('URL: ${options.uri}');
    AppLogger.info('请求头: ${options.headers}');
    
    if (options.data != null) {
      AppLogger.info('请求体: ${options.data}');
    }
    
    if (options.queryParameters.isNotEmpty) {
      AppLogger.info('查询参数: ${options.queryParameters}');
    }
    
    super.onRequest(options, handler);
  }
  
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    AppLogger.info('✅ 响应成功');
    AppLogger.info('状态码: ${response.statusCode}');
    AppLogger.info('响应头: ${response.headers}');
    AppLogger.info('响应体: ${response.data}');
    
    super.onResponse(response, handler);
  }
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    AppLogger.error('❌ 请求失败');
    AppLogger.error('错误类型: ${err.type}');
    AppLogger.error('错误信息: ${err.message}');
    
    if (err.response != null) {
      AppLogger.error('响应状态码: ${err.response?.statusCode}');
      AppLogger.error('响应数据: ${err.response?.data}');
    }
    
    super.onError(err, handler);
  }
}