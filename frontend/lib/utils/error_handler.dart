import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

/// 统一的错误处理工具类
///
/// 将各种异常转换为用户友好的错误消息
class ErrorHandler {
  /// 将异常转换为用户友好的错误消息
  static String getErrorMessage(dynamic error, {String? defaultMessage}) {
    // DioException 处理
    if (error is DioException) {
      return _handleDioError(error);
    }

    // SocketException 处理
    if (error is SocketException) {
      return '网络连接失败，请检查网络设置';
    }

    // HttpException 处理
    if (error is HttpException) {
      return '服务器连接异常，请稍后重试';
    }

    // FormatException 处理
    if (error is FormatException) {
      return '数据格式错误，请稍后重试';
    }

    // TimeoutException 处理
    if (error.runtimeType.toString().contains('TimeoutException')) {
      return '请求超时，请检查网络后重试';
    }

    // 默认消息
    return defaultMessage ?? '操作失败，请稍后重试';
  }

  /// 处理 Dio 异常
  static String _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return '连接超时，请检查网络后重试';
      case DioExceptionType.sendTimeout:
        return '发送超时，请检查网络后重试';
      case DioExceptionType.receiveTimeout:
        return '响应超时，请检查网络后重试';
      case DioExceptionType.badCertificate:
        return '安全证书错误，请联系客服';
      case DioExceptionType.badResponse:
        return _handleBadResponse(error.response);
      case DioExceptionType.cancel:
        return '请求已取消';
      case DioExceptionType.connectionError:
        return '网络连接失败，请检查网络设置';
      case DioExceptionType.unknown:
        // 检查是否是网络相关错误
        if (error.error is SocketException) {
          return '网络连接失败，请检查网络设置';
        }
        return '网络异常，请稍后重试';
    }
  }

  /// 处理 HTTP 响应错误
  static String _handleBadResponse(Response? response) {
    if (response == null) {
      return '服务器无响应，请稍后重试';
    }

    final statusCode = response.statusCode ?? 0;

    // 尝试从响应体提取错误消息
    final errorMsg = _extractErrorMessage(response.data);
    if (errorMsg != null) {
      return errorMsg;
    }

    // 根据状态码返回通用消息
    switch (statusCode) {
      case 400:
        return '请求参数错误';
      case 401:
        return '登录已过期，请重新登录';
      case 403:
        return '没有权限执行此操作';
      case 404:
        return '请求的资源不存在';
      case 405:
        return '请求方式不支持';
      case 408:
        return '请求超时，请稍后重试';
      case 409:
        return '操作冲突，请刷新后重试';
      case 413:
        return '上传的内容过大';
      case 429:
        return '请求过于频繁，请稍后重试';
      case 500:
        return '服务器内部错误，请稍后重试';
      case 502:
        return '服务器网关错误，请稍后重试';
      case 503:
        return '服务暂时不可用，请稍后重试';
      case 504:
        return '服务器响应超时，请稍后重试';
      default:
        if (statusCode >= 500) {
          return '服务器错误，请稍后重试';
        } else if (statusCode >= 400) {
          return '请求错误，请稍后重试';
        }
        return '网络异常，请稍后重试';
    }
  }

  /// 从响应体提取错误消息
  static String? _extractErrorMessage(dynamic data) {
    if (data == null) return null;

    try {
      if (data is Map<String, dynamic>) {
        // 尝试多种常见的错误消息字段
        final message = data['message'] ??
            data['msg'] ??
            data['error'] ??
            data['error_message'] ??
            (data['base'] as Map?)?['msg'];

        if (message != null && message.toString().isNotEmpty) {
          final msg = message.toString();
          // 过滤掉技术性错误信息，返回友好提示
          if (_isTechnicalError(msg)) {
            return null;
          }
          return msg;
        }
      }
    } catch (_) {
      // 解析失败，返回 null
    }
    return null;
  }

  /// 判断是否是技术性错误消息（不应该直接展示给用户）
  static bool _isTechnicalError(String message) {
    final lowerMsg = message.toLowerCase();
    return lowerMsg.contains('exception') ||
        lowerMsg.contains('error:') ||
        lowerMsg.contains('stack trace') ||
        lowerMsg.contains('null pointer') ||
        lowerMsg.contains('connection refused') ||
        lowerMsg.contains('socket') ||
        lowerMsg.contains('timeout') ||
        lowerMsg.contains('failed host lookup') ||
        lowerMsg.contains('errno') ||
        lowerMsg.contains('econnrefused') ||
        lowerMsg.contains('network is unreachable');
  }

  /// 在 SnackBar 中显示错误消息
  static void showError(
    BuildContext context,
    dynamic error, {
    String? prefix,
    String? defaultMessage,
    Duration duration = const Duration(seconds: 3),
  }) {
    final message = getErrorMessage(error, defaultMessage: defaultMessage);
    final displayMessage = prefix != null ? '$prefix：$message' : message;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(displayMessage),
        backgroundColor: Colors.redAccent,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// 显示成功消息
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// 显示普通提示消息
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
