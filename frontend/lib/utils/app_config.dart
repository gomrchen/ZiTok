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
///
/// 优化策略：优先保证用户播放体验流畅，其次考虑内存占用
/// 现代设备内存充足，适当增加缓存可显著提升体验
class VideoPerformanceConfig {
  VideoPerformanceConfig._();

  /// 预加载视频数量
  /// 增加预加载数量确保滑动时视频已就绪，减少加载等待
  static int get preloadCount => 4;

  /// 预加载窗口大小（当前视频前后各预加载几个）
  /// 前后各预加载2个，确保无论向上还是向下滑动都流畅
  static int get preloadWindow => 2;

  /// 预加载延迟（毫秒）
  /// 降低延迟，更快开始预加载下一个视频
  static int get preloadDelayMs => 100;

  /// 视频缓冲策略 - 最小缓冲时间
  /// 保持较大的最小缓冲，减少播放中的卡顿
  static Duration get minBufferDuration => const Duration(seconds: 8);

  /// 视频缓冲策略 - 最大缓冲时间
  /// 增加最大缓冲，让用户在网络波动时也能流畅观看
  static Duration get maxBufferDuration => const Duration(seconds: 60);

  /// 视频缓冲策略 - 播放前最小缓冲
  /// 降低启播门槛，让视频更快开始播放
  static Duration get bufferForPlayback => const Duration(milliseconds: 500);

  /// 视频缓冲策略 - 重新缓冲后播放
  /// 卡顿后快速恢复播放
  static Duration get bufferForPlaybackAfterRebuffer => const Duration(seconds: 1);

  /// 是否启用硬件加速
  static bool get enableHardwareAcceleration => true;

  /// 视频内存缓存大小（MB）
  /// 增加内存缓存，减少重复加载
  static int get memoryCacheSizeMB => 200;

  /// 视频磁盘缓存大小（MB）
  /// 增加磁盘缓存，已看过的视频可快速重播
  static int get diskCacheSizeMB => 800;

  /// 封面图缓存数量
  /// 增加封面缓存，列表滑动更流畅
  static int get coverCacheCount => 100;

  /// 视频控制器池大小
  /// 增加控制器池，支持更多视频同时准备就绪
  static int get controllerPoolSize => 5;

  /// 是否启用智能预加载（根据网络状况调整）
  static bool get enableSmartPreload => true;

  /// 视频加载超时时间
  /// 适当的超时时间，既不会太快放弃也不会等待太久
  static Duration get loadTimeout => const Duration(seconds: 20);

  /// 视频首帧加载超时时间（首帧显示后用户体验更好）
  static Duration get firstFrameTimeout => const Duration(seconds: 5);

  /// 是否启用后台预加载（在WiFi下更激进地预加载）
  static bool get enableBackgroundPreload => true;

  /// 后台预加载视频数量（WiFi环境下）
  static int get backgroundPreloadCount => 6;

  /// 视频质量自动调节（根据网络状况）
  static bool get enableAdaptiveQuality => true;

  /// 快速滑动时是否暂停预加载（避免资源浪费）
  static bool get pausePreloadOnFastScroll => true;

  /// 快速滑动检测阈值（毫秒内切换视频数）
  static int get fastScrollThreshold => 3;
}

/// 动画性能配置
///
/// 优化策略：保持流畅的动画效果，提升用户交互体验
class AnimationConfig {
  AnimationConfig._();

  /// 是否启用高性能动画模式
  static bool get highPerformanceMode => true;

  /// 列表滚动物理效果
  static Duration get scrollAnimationDuration => const Duration(milliseconds: 200);

  /// 页面切换动画时长（稍快一点，让切换更流畅）
  static Duration get pageTransitionDuration => const Duration(milliseconds: 250);

  /// 淡入淡出动画时长
  static Duration get fadeDuration => const Duration(milliseconds: 180);

  /// 点赞动画时长
  static Duration get likeAnimationDuration => const Duration(milliseconds: 280);

  /// 是否启用列表项动画（保持开启，增强视觉效果）
  static bool get enableListItemAnimation => true;

  /// 骨架屏闪烁动画周期
  static Duration get shimmerDuration => const Duration(milliseconds: 1000);

  /// 视频切换淡入动画时长
  static Duration get videoFadeDuration => const Duration(milliseconds: 250);

  /// 弹窗动画时长
  static Duration get dialogAnimationDuration => const Duration(milliseconds: 220);

  /// 底部Sheet动画时长
  static Duration get bottomSheetDuration => const Duration(milliseconds: 280);
}

/// 网络性能配置
///
/// 优化策略：加快资源加载速度，增大缓存容量
class NetworkConfig {
  NetworkConfig._();

  /// 连接超时时间
  static Duration get connectTimeout => const Duration(seconds: 15);

  /// 接收超时时间
  static Duration get receiveTimeout => const Duration(seconds: 25);

  /// 是否启用请求日志拦截器（仅开发模式）
  static bool get enableLogInterceptor => !AppConfig.isProduction;

  /// 图片缓存最大数量（增加缓存，减少重复加载）
  static int get imageCacheMaxCount => 300;

  /// 图片缓存最大内存（MB）
  static int get imageCacheMaxSizeMB => 200;

  /// 并发请求数限制（增加并发，加快资源加载）
  static int get maxConcurrentRequests => 8;

  /// 视频流并发请求数（专门用于视频加载）
  static int get maxVideoConcurrentRequests => 4;

  /// 是否启用HTTP/2（提升传输效率）
  static bool get enableHttp2 => true;

  /// 是否启用连接复用
  static bool get enableConnectionReuse => true;

  /// 连接池大小
  static int get connectionPoolSize => 10;

  /// DNS缓存时间（秒）
  static int get dnsCacheDurationSeconds => 300;

  /// 是否启用预连接（提前建立连接）
  static bool get enablePreconnect => true;
}

/// 内存管理配置
///
/// 优化策略：适度放宽内存限制，优先保证播放流畅
/// 现代手机内存充足（通常4GB以上），适当增加缓存可显著提升体验
class MemoryConfig {
  MemoryConfig._();

  /// 是否启用激进的内存回收（关闭以保持更多缓存）
  static bool get aggressiveGC => false;

  /// 列表项缓存范围（可视区域外的像素数）
  /// 增大缓存范围，让列表滑动更流畅
  static double get cacheExtent => 1000;

  /// 是否启用图片内存缓存
  static bool get enableImageMemoryCache => true;

  /// 页面离开时是否释放资源（关闭以支持快速返回）
  static bool get releaseResourcesOnPageLeave => false;

  /// 视频控制器保活时间（秒）
  /// 离开视频页面后控制器保持多久，便于快速返回
  static int get controllerKeepAliveSeconds => 60;

  /// 最大同时保活的视频控制器数量
  static int get maxKeepAliveControllers => 3;

  /// 是否启用智能内存管理（低内存时自动释放）
  static bool get enableSmartMemoryManagement => true;

  /// 低内存阈值（MB），低于此值时开始释放资源
  static int get lowMemoryThresholdMB => 200;

  /// 是否在后台时释放非必要资源
  static bool get releaseOnBackground => true;

  /// 后台资源释放延迟（秒），避免频繁切换时资源抖动
  static int get backgroundReleaseDelaySeconds => 30;

  /// 列表预渲染数量
  static int get listPreRenderCount => 5;
}
