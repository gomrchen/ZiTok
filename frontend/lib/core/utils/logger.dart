/*
 * 文件版本号: 1.0.0
 * 文件功能说明: 应用日志工具类，提供统一的日志记录接口，支持多级别日志输出和格式化显示
 * 当前已知问题:
 *   - 缺少日志文件持久化功能
 *   - 没有日志级别动态配置机制
 *   - 缺少日志上传和远程监控功能
 * 修改需求说明:
 *   - 添加日志文件本地存储功能
 *   - 实现日志级别动态配置，支持运行时调整
 *   - 集成远程日志上传功能，便于线上问题排查
 *   - 添加日志性能监控，避免影响应用性能
 */

import 'package:logger/logger.dart';

/// 应用日志工具类
/// 提供统一的日志记录功能，支持不同级别的日志输出
class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );

  /// 调试日志
  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// 信息日志
  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// 警告日志
  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// 错误日志
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// 致命错误日志
  static void fatal(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }

  /// 跟踪日志
  static void trace(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.t(message, error: error, stackTrace: stackTrace);
  }
}