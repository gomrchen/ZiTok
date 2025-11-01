/*
 * 文件版本号: 1.0.0
 * 文件功能说明: 错误处理拦截器，统一捕获和转换网络请求过程中的各种异常，提供标准化的错误响应
 * 当前已知问题:
 *   - 错误消息硬编码，缺少国际化支持
 *   - 缺少错误统计和上报机制
 *   - 某些特殊错误场景处理不够完善
 * 修改需求说明:
 *   - 添加错误消息国际化支持
 *   - 集成错误统计和上报功能，便于问题追踪
 *   - 完善各种网络异常场景的处理逻辑
 *   - 添加用户友好的错误提示机制
 */

import 'package:dio/dio.dart';
import '../../utils/logger.dart';
import '../exceptions/api_exception.dart';

/// 错误处理拦截器
/// 统一处理和转换网络请求错误
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    ApiException apiException;
    
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
        apiException = const ApiException(
          code: 'CONNECTION_TIMEOUT',
          message: '连接超时，请检查网络连接',
          statusCode: null,
        );
        break;
        
      case DioExceptionType.sendTimeout:
        apiException = const ApiException(
          code: 'SEND_TIMEOUT',
          message: '请求发送超时',
          statusCode: null,
        );
        break;
        
      case DioExceptionType.receiveTimeout:
        apiException = const ApiException(
          code: 'RECEIVE_TIMEOUT',
          message: '响应接收超时',
          statusCode: null,
        );
        break;
        
      case DioExceptionType.badResponse:
        final statusCode = err.response?.statusCode;
        final responseData = err.response?.data;
        
        String message = '请求失败';
        String code = 'BAD_RESPONSE';
        
        if (responseData is Map<String, dynamic>) {
          message = responseData['message'] ?? message;
          code = responseData['code'] ?? code;
        }
        
        apiException = ApiException(
          code: code,
          message: message,
          statusCode: statusCode,
          data: responseData,
        );
        break;
        
      case DioExceptionType.cancel:
        apiException = const ApiException(
          code: 'REQUEST_CANCELLED',
          message: '请求已取消',
          statusCode: null,
        );
        break;
        
      case DioExceptionType.unknown:
        apiException = const ApiException(
          code: 'NETWORK_ERROR',
          message: '网络连接异常，请检查网络设置',
          statusCode: null,
        );
        break;
        
      default:
        apiException = ApiException(
          code: 'UNKNOWN_ERROR',
          message: '未知错误: ${err.message}',
          statusCode: null,
        );
    }
    
    AppLogger.error('API错误: ${apiException.toString()}');
    
    // 将DioException转换为ApiException
    final convertedError = DioException(
      requestOptions: err.requestOptions,
      error: apiException,
      type: err.type,
      response: err.response,
    );
    
    super.onError(convertedError, handler);
  }
}