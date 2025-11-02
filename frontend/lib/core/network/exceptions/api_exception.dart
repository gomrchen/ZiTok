/*
 * 文件版本号: 1.0.0
 * 文件功能说明: API异常处理类，统一封装网络请求过程中的各种异常情况，提供错误分类和处理机制
 * 当前已知问题:
 *   - 缺少本地化错误消息支持
 *   - 错误码定义不够完整，需要更详细的分类
 *   - 缺少错误日志记录机制
 * 修改需求说明:
 *   - 添加国际化错误消息支持
 *   - 完善错误码体系，增加业务相关的错误分类
 *   - 集成日志系统，记录异常详情便于调试
 *   - 添加错误重试建议机制
 */

/// API异常类
/// 统一封装所有API相关的异常信息
class ApiException implements Exception {
  /// 错误代码
  final String code;
  
  /// 错误消息
  final String message;
  
  /// HTTP状态码
  final int? statusCode;
  
  /// 额外数据
  final dynamic data;
  
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.data,
  });
  
  /// 是否为网络错误
  bool get isNetworkError => statusCode == null;
  
  /// 是否为服务器错误
  bool get isServerError => statusCode != null && statusCode! >= 500;
  
  /// 是否为客户端错误
  bool get isClientError => statusCode != null && statusCode! >= 400 && statusCode! < 500;
  
  /// 是否为未授权错误
  bool get isUnauthorized => statusCode == 401;
  
  /// 是否为禁止访问错误
  bool get isForbidden => statusCode == 403;
  
  /// 是否为资源未找到错误
  bool get isNotFound => statusCode == 404;
  
  @override
  String toString() {
    return 'ApiException{code: $code, message: $message, statusCode: $statusCode, data: $data}';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is ApiException &&
        other.code == code &&
        other.message == message &&
        other.statusCode == statusCode &&
        other.data == data;
  }
  
  @override
  int get hashCode {
    return code.hashCode ^
        message.hashCode ^
        statusCode.hashCode ^
        data.hashCode;
  }
}

/// 常用API异常
class CommonApiExceptions {
  static const ApiException networkError = ApiException(
    code: 'NETWORK_ERROR',
    message: '网络连接失败，请检查网络设置',
  );
  
  static const ApiException serverError = ApiException(
    code: 'SERVER_ERROR',
    message: '服务器内部错误，请稍后重试',
    statusCode: 500,
  );
  
  static const ApiException unauthorized = ApiException(
    code: 'UNAUTHORIZED',
    message: '未授权访问，请重新登录',
    statusCode: 401,
  );
  
  static const ApiException forbidden = ApiException(
    code: 'FORBIDDEN',
    message: '访问被禁止，权限不足',
    statusCode: 403,
  );
  
  static const ApiException notFound = ApiException(
    code: 'NOT_FOUND',
    message: '请求的资源不存在',
    statusCode: 404,
  );
  
  static const ApiException timeout = ApiException(
    code: 'TIMEOUT',
    message: '请求超时，请稍后重试',
  );
}