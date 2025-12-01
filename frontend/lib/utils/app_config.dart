import 'package:flutter/foundation.dart';

/// 应用全局配置
///
/// 集中管理生产环境与开发环境的配置差异
class AppConfig {
  AppConfig._();

  /// 是否为生产模式（Release 构建）
  static bool get isProduction => kReleaseMode;

  /// 是否为开发模式（Debug 构建）
  static bool get isDevelopment => kDebugMode;

  /// 是否启用日志输出
  static bool get enableLogging => !isProduction;

  /// 是否启用性能监控日志
  static bool get enablePerformanceLogging => !isProduction;

  /// 是否启用网络请求日志
  static bool get enableNetworkLogging => !isProduction;

  /// 是否启用视频调试日志
  static bool get enableVideoLogging => !isProduction;

  /// 条件日志输出（仅开发模式）
  static void log(String message, {String? tag}) {
    if (enableLogging) {
      final prefix = tag != null ? '[$tag] ' : '';
      debugPrint('$prefix$message');
    }
  }

  /// 性能日志输出
  static void perfLog(String message) {
    if (enablePerformanceLogging) {
      debugPrint('[PERF] $message');
    }
  }

  /// 网络日志输出
  static void netLog(String message) {
    if (enableNetworkLogging) {
      debugPrint('[NET] $message');
    }
  }

  /// 视频日志输出
  static void videoLog(String message) {
    if (enableVideoLogging) {
      debugPrint('[VIDEO] $message');
    }
  }
}

/// 视频播放器性能配置
class VideoPerformanceConfig {
  VideoPerformanceConfig._();

  /// 预加载视频数量（生产模式减少内存占用）
  static int get preloadCount => AppConfig.isProduction ? 2 : 3;

  /// 预加载窗口大小（当前视频前后各预加载几个）
  static int get preloadWindow => AppConfig.isProduction ? 1 : 2;

  /// 预加载延迟（毫秒），避免快速滑动时频繁加载
  static int get preloadDelayMs => AppConfig.isProduction ? 200 : 300;

  /// 视频缓冲策略 - 最小缓冲时间（秒）
  static Duration get minBufferDuration =>
      AppConfig.isProduction ? const Duration(seconds: 5) : const Duration(seconds: 3);

  /// 视频缓冲策略 - 最大缓冲时间（秒）
  static Duration get maxBufferDuration =>
      AppConfig.isProduction ? const Duration(seconds: 30) : const Duration(seconds: 20);

  /// 视频缓冲策略 - 播放前最小缓冲（生产模式更快启播）
  static Duration get bufferForPlayback =>
      AppConfig.isProduction ? const Duration(milliseconds: 800) : const Duration(milliseconds: 1500);

  /// 视频缓冲策略 - 重新缓冲后播放
  static Duration get bufferForPlaybackAfterRebuffer =>
      AppConfig.isProduction ? const Duration(seconds: 2) : const Duration(seconds: 3);

  /// 是否启用硬件加速
  static bool get enableHardwareAcceleration => true;

  /// 视频内存缓存大小（MB）
  static int get memoryCacheSizeMB => AppConfig.isProduction ? 100 : 150;

  /// 视频磁盘缓存大小（MB）
  static int get diskCacheSizeMB => AppConfig.isProduction ? 500 : 300;

  /// 封面图缓存数量
  static int get coverCacheCount => AppConfig.isProduction ? 50 : 30;

  /// 视频控制器池大小
  static int get controllerPoolSize => AppConfig.isProduction ? 3 : 4;

  /// 是否启用智能预加载（根据网络状况调整）
  static bool get enableSmartPreload => true;

  /// 视频加载超时时间
  static Duration get loadTimeout =>
      AppConfig.isProduction ? const Duration(seconds: 15) : const Duration(seconds: 30);
}

/// 动画性能配置
class AnimationConfig {
  AnimationConfig._();

  /// 是否启用高性能动画模式
  static bool get highPerformanceMode => AppConfig.isProduction;

  /// 列表滚动物理效果
  static Duration get scrollAnimationDuration =>
      const Duration(milliseconds: 250);

  /// 页面切换动画时长
  static Duration get pageTransitionDuration =>
      AppConfig.isProduction
          ? const Duration(milliseconds: 280)
          : const Duration(milliseconds: 350);

  /// 淡入淡出动画时长
  static Duration get fadeDuration =>
      const Duration(milliseconds: 200);

  /// 点赞动画时长
  static Duration get likeAnimationDuration =>
      const Duration(milliseconds: 300);

  /// 是否启用列表项动画
  static bool get enableListItemAnimation => !AppConfig.isProduction;

  /// 骨架屏闪烁动画周期
  static Duration get shimmerDuration =>
      const Duration(milliseconds: 1200);
}

/// 网络性能配置
class NetworkConfig {
  NetworkConfig._();

  /// 连接超时时间
  static Duration get connectTimeout =>
      AppConfig.isProduction
          ? const Duration(seconds: 15)
          : const Duration(seconds: 30);

  /// 接收超时时间
  static Duration get receiveTimeout =>
      AppConfig.isProduction
          ? const Duration(seconds: 20)
          : const Duration(seconds: 30);

  /// 是否启用请求日志拦截器
  static bool get enableLogInterceptor => !AppConfig.isProduction;

  /// 图片缓存最大数量
  static int get imageCacheMaxCount => AppConfig.isProduction ? 200 : 100;

  /// 图片缓存最大内存（MB）
  static int get imageCacheMaxSizeMB => AppConfig.isProduction ? 150 : 100;

  /// 并发请求数限制
  static int get maxConcurrentRequests => AppConfig.isProduction ? 6 : 4;
}

/// 内存管理配置
class MemoryConfig {
  MemoryConfig._();

  /// 是否启用激进的内存回收
  static bool get aggressiveGC => AppConfig.isProduction;

  /// 列表项缓存范围（可视区域外的项数）
  static double get cacheExtent => AppConfig.isProduction ? 500 : 800;

  /// 是否启用图片内存缓存
  static bool get enableImageMemoryCache => true;

  /// 页面离开时是否释放资源
  static bool get releaseResourcesOnPageLeave => AppConfig.isProduction;
}
