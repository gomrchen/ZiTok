import 'dart:async';
import 'dart:collection';
import 'package:video_player/video_player.dart';
import 'video_cache_service.dart';
import 'video_performance_monitor.dart';
import 'network_aware_loader.dart';
import '../../utils/app_config.dart';

/// 视频预加载配置（从 AppConfig 读取生产/开发模式配置）
class PreloadConfig {
  /// 预加载窗口大小（当前视频前后各预加载几个）
  int get preloadWindow => VideoPerformanceConfig.preloadWindow;

  /// 最大同时保持的控制器数量
  int get maxControllers => VideoPerformanceConfig.controllerPoolSize;

  /// 预加载延迟（毫秒），避免快速滑动时频繁加载
  int get preloadDelayMs => VideoPerformanceConfig.preloadDelayMs;

  /// 是否启用智能预加载（根据网络状况调整）
  bool get smartPreload => VideoPerformanceConfig.enableSmartPreload;

  const PreloadConfig();
}

/// 预加载视频项
class PreloadItem {
  final String videoId;
  final String videoUrl;
  final int index;

  const PreloadItem({
    required this.videoId,
    required this.videoUrl,
    required this.index,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PreloadItem && videoId == other.videoId;

  @override
  int get hashCode => videoId.hashCode;
}

/// 控制器包装，包含额外元数据
class ControllerWrapper {
  final VideoPlayerController controller;
  final String videoId;
  final DateTime createdAt;
  DateTime lastAccessedAt;  // 最后访问时间（用于 LRU）
  bool isPreloaded;
  bool isPlaying;

  ControllerWrapper({
    required this.controller,
    required this.videoId,
    required this.createdAt,
    this.isPreloaded = false,
    this.isPlaying = false,
  }) : lastAccessedAt = createdAt;

  Duration get age => DateTime.now().difference(createdAt);

  /// 标记为已访问（更新 LRU 时间戳）
  void markAccessed() {
    lastAccessedAt = DateTime.now();
  }
}

/// 视频预加载管理器
///
/// 功能：
/// - 智能预加载：根据当前播放位置预加载前后视频
/// - LRU缓存策略：自动清理最久未使用的控制器
/// - 网络感知：根据网络状况动态调整预加载策略
/// - 防抖加载：避免快速滑动时频繁创建控制器
class VideoPreloadManager {
  static VideoPreloadManager? _instance;
  static VideoPreloadManager get instance => _instance ??= VideoPreloadManager._();

  VideoPreloadManager._();

  final PreloadConfig _config = const PreloadConfig();
  final LinkedHashMap<String, ControllerWrapper> _controllers = LinkedHashMap();
  final Set<String> _preloading = {};

  Timer? _preloadDebouncer;
  int _currentIndex = 0;
  List<PreloadItem> _videoList = [];

  VideoCacheService? _cacheService;
  VideoPerformanceMonitor? _monitor;
  NetworkAwareLoader? _networkLoader;

  /// 快速滑动检测
  DateTime? _lastIndexChangeTime;
  int _fastScrollCount = 0;
  static const int _fastScrollThreshold = 3; // 1秒内切换3次视为快速滑动
  static const Duration _fastScrollWindow = Duration(seconds: 1);

  /// 初始化管理器
  Future<void> init({
    VideoCacheService? cacheService,
    VideoPerformanceMonitor? monitor,
  }) async {
    _cacheService = cacheService;
    _monitor = monitor;

    // 初始化网络感知加载器
    _networkLoader = NetworkAwareLoader.instance;
    await _networkLoader!.init();

    // 监听网络状态变化
    _networkLoader!.addListener(_onNetworkStatusChanged);

    AppConfig.videoLog('VideoPreloadManager: initialized with network-aware loading');
  }

  /// 网络状态变化处理
  void _onNetworkStatusChanged(NetworkStatus status) {
    AppConfig.videoLog('VideoPreloadManager: network status changed to ${status.quality}');
    // 网络变好时，触发预加载
    if (status.quality != NetworkQuality.veryPoor) {
      _schedulePreload();
    }
  }

  /// 设置视频列表
  void setVideoList(List<PreloadItem> videos) {
    _videoList = videos;
    AppConfig.videoLog('VideoPreloadManager: video list updated, count=${videos.length}');
  }

  /// 更新当前播放索引，触发预加载
  void updateCurrentIndex(int index) {
    if (index == _currentIndex && _controllers.isNotEmpty) return;

    // 检测快速滑动
    final now = DateTime.now();
    if (_lastIndexChangeTime != null &&
        now.difference(_lastIndexChangeTime!) < _fastScrollWindow) {
      _fastScrollCount++;
    } else {
      _fastScrollCount = 1;
    }
    _lastIndexChangeTime = now;

    final isFastScrolling = _fastScrollCount >= _fastScrollThreshold;

    _currentIndex = index;

    // 更新优先级：当前视频最高优先级
    if (index >= 0 && index < _videoList.length) {
      final currentVideo = _videoList[index];
      _networkLoader?.setPriority(currentVideo.videoId, 0);

      // 设置相邻视频优先级
      for (int i = 1; i <= _config.preloadWindow; i++) {
        if (index + i < _videoList.length) {
          _networkLoader?.setPriority(_videoList[index + i].videoId, i);
        }
        if (index - i >= 0) {
          _networkLoader?.setPriority(_videoList[index - i].videoId, i);
        }
      }
    }

    // 快速滑动时延长防抖时间，避免频繁加载
    if (isFastScrolling) {
      AppConfig.videoLog('VideoPreloadManager: fast scrolling detected, pausing preload');
      _preloadDebouncer?.cancel();
      _preloadDebouncer = Timer(
        const Duration(milliseconds: 500), // 快速滑动时等待更久
        _executePreload,
      );
    } else {
      _schedulePreload();
    }
  }

  /// 获取或创建视频控制器
  Future<VideoPlayerController?> getController(String videoId, String videoUrl) async {
    // 检查是否已存在
    final existing = _controllers[videoId];
    if (existing != null) {
      // 更新访问时间（LRU）
      existing.markAccessed();
      // 移到末尾（LinkedHashMap 顺序）
      _controllers.remove(videoId);
      _controllers[videoId] = existing;
      AppConfig.videoLog('VideoPreloadManager: reuse controller for $videoId');
      return existing.controller;
    }

    // 创建新控制器
    final controller = await _createController(videoId, videoUrl);
    return controller;
  }

  /// 获取已预加载的控制器（不创建新的）
  VideoPlayerController? getPreloadedController(String videoId) {
    final wrapper = _controllers[videoId];
    if (wrapper != null && wrapper.isPreloaded) {
      // 更新访问时间（LRU）
      wrapper.markAccessed();
      // 移到末尾（LinkedHashMap 顺序）
      _controllers.remove(videoId);
      _controllers[videoId] = wrapper;
      return wrapper.controller;
    }
    return null;
  }

  /// 标记控制器正在播放
  void markAsPlaying(String videoId) {
    final wrapper = _controllers[videoId];
    if (wrapper != null) {
      wrapper.isPlaying = true;
    }
  }

  /// 标记控制器停止播放
  void markAsStopped(String videoId) {
    final wrapper = _controllers[videoId];
    if (wrapper != null) {
      wrapper.isPlaying = false;
    }
  }

  /// 暂停所有非当前播放的视频
  void pauseAllExcept(String? currentVideoId) {
    for (final entry in _controllers.entries) {
      if (entry.key != currentVideoId) {
        entry.value.controller.pause();
        entry.value.isPlaying = false;
      }
    }
  }

  /// 暂停所有视频
  void pauseAll() {
    for (final wrapper in _controllers.values) {
      wrapper.controller.pause();
      wrapper.isPlaying = false;
    }
    AppConfig.videoLog('VideoPreloadManager: all videos paused');
  }

  /// 释放指定控制器
  void releaseController(String videoId) {
    final wrapper = _controllers.remove(videoId);
    if (wrapper != null) {
      wrapper.controller.dispose();
      AppConfig.videoLog('VideoPreloadManager: released controller for $videoId');
    }
  }

  /// 释放所有控制器
  void releaseAll() {
    for (final wrapper in _controllers.values) {
      wrapper.controller.dispose();
    }
    _controllers.clear();
    _preloading.clear();
    _preloadDebouncer?.cancel();
    AppConfig.videoLog('VideoPreloadManager: all controllers released');
  }

  /// 调度预加载（防抖）
  void _schedulePreload() {
    _preloadDebouncer?.cancel();
    _preloadDebouncer = Timer(
      Duration(milliseconds: _config.preloadDelayMs),
      _executePreload,
    );
  }

  /// 执行预加载
  Future<void> _executePreload() async {
    if (_videoList.isEmpty) return;

    // 获取网络感知的预加载数量
    final smartPreloadCount = _getSmartPreloadCount();

    // 网络极差时，不预加载，只确保当前视频能播放
    if (smartPreloadCount == 0) {
      AppConfig.videoLog('VideoPreloadManager: network too slow, skip preloading');
      return;
    }

    // 计算需要预加载的索引范围（根据网络状况动态调整）
    final windowSize = smartPreloadCount.clamp(1, _config.preloadWindow);
    final start = (_currentIndex - windowSize).clamp(0, _videoList.length - 1);
    final end = (_currentIndex + windowSize).clamp(0, _videoList.length - 1);

    // 收集需要预加载的视频
    final toPreload = <PreloadItem>[];
    for (int i = start; i <= end; i++) {
      final item = _videoList[i];
      if (!_controllers.containsKey(item.videoId) && !_preloading.contains(item.videoId)) {
        // 检查网络感知加载器是否允许加载
        if (_networkLoader?.shouldLoad(item.videoId) ?? true) {
          toPreload.add(item);
        }
      }
    }

    // 按距离当前索引排序（优先加载近的）
    toPreload.sort((a, b) {
      final distA = (a.index - _currentIndex).abs();
      final distB = (b.index - _currentIndex).abs();
      return distA.compareTo(distB);
    });

    // 限制预加载数量
    final limited = toPreload.take(smartPreloadCount + 1); // +1 包含当前视频

    AppConfig.videoLog('VideoPreloadManager: preloading ${limited.length} videos (network: ${_networkLoader?.currentStatus.quality})');

    // 串行预加载（低带宽时避免竞争）
    // 网络差时串行，网络好时并行
    if (_networkLoader?.currentStatus.quality == NetworkQuality.veryPoor ||
        _networkLoader?.currentStatus.quality == NetworkQuality.poor) {
      // 串行加载，优先级高的先加载
      for (final item in limited) {
        await _preloadVideo(item);
      }
    } else {
      // 并行预加载
      await Future.wait(limited.map((item) => _preloadVideo(item)));
    }

    // 不再主动清理控制器，让 LRU 策略在容量不足时自动清理
    // 这样用户滑回之前的视频时可以复用已缓存的控制器
  }

  /// 根据网络状况获取预加载数量
  int _getSmartPreloadCount() {
    if (_networkLoader != null) {
      return _networkLoader!.getRecommendedPreloadCount();
    }
    // 默认返回配置的窗口大小
    return _config.preloadWindow;
  }

  /// 预加载单个视频
  Future<void> _preloadVideo(PreloadItem item) async {
    if (_preloading.contains(item.videoId)) return;
    _preloading.add(item.videoId);

    try {
      final controller = await _createController(item.videoId, item.videoUrl, isPreload: true);
      if (controller != null) {
        AppConfig.videoLog('VideoPreloadManager: preloaded ${item.videoId}');
      }
    } catch (e) {
      AppConfig.videoLog('VideoPreloadManager: preload failed for ${item.videoId}: $e');
    } finally {
      _preloading.remove(item.videoId);
    }
  }

  /// 创建视频控制器
  Future<VideoPlayerController?> _createController(
    String videoId,
    String videoUrl, {
    bool isPreload = false,
  }) async {
    // 检查是否需要清理旧控制器
    _ensureCapacity();

    final startTime = DateTime.now();
    _monitor?.recordLoadStart(videoId);

    try {
      // 尝试从缓存获取
      String actualUrl = videoUrl;
      bool fromCache = false;
      if (_cacheService != null) {
        final cachedPath = await _cacheService!.getCachedVideoPath(videoUrl);
        if (cachedPath != null) {
          actualUrl = cachedPath;
          fromCache = true;
          AppConfig.videoLog('VideoPreloadManager: using cached video for $videoId');
        }
      }

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(actualUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );

      await controller.initialize();

      final loadTime = DateTime.now().difference(startTime);
      _monitor?.recordLoadComplete(videoId, loadTime);

      // 记录网络速度样本（仅非缓存加载）
      if (!fromCache && controller.value.isInitialized) {
        // 估算下载的数据量（使用视频时长和码率估算）
        final duration = controller.value.duration;
        if (duration.inSeconds > 0) {
          // 假设初始化加载了约3秒的数据，按平均码率1Mbps估算
          // 实际情况会有差异，但可以作为参考
          final estimatedBytes = (duration.inSeconds.clamp(1, 5) * 125 * 1024); // ~1Mbps
          _networkLoader?.recordSpeedSample(estimatedBytes, loadTime);
        }
      }

      final wrapper = ControllerWrapper(
        controller: controller,
        videoId: videoId,
        createdAt: DateTime.now(),
        isPreloaded: isPreload,
      );

      _controllers[videoId] = wrapper;

      AppConfig.videoLog('VideoPreloadManager: created controller for $videoId in ${loadTime.inMilliseconds}ms (cache: $fromCache)');
      return controller;
    } catch (e) {
      _monitor?.recordLoadError(videoId, e.toString());
      AppConfig.videoLog('VideoPreloadManager: failed to create controller for $videoId: $e');
      return null;
    }
  }

  /// 确保控制器数量不超过限制（使用 LRU 策略）
  void _ensureCapacity() {
    while (_controllers.length >= _config.maxControllers) {
      // 找到最久未访问且非播放中的控制器（真正的 LRU）
      String? toRemove;
      DateTime? oldestAccessTime;

      for (final entry in _controllers.entries) {
        if (!entry.value.isPlaying) {
          if (oldestAccessTime == null ||
              entry.value.lastAccessedAt.isBefore(oldestAccessTime)) {
            oldestAccessTime = entry.value.lastAccessedAt;
            toRemove = entry.key;
          }
        }
      }

      if (toRemove != null) {
        final wrapper = _controllers.remove(toRemove);
        wrapper?.controller.dispose();
        AppConfig.videoLog('VideoPreloadManager: evicted LRU controller for $toRemove (capacity)');
      } else {
        // 所有控制器都在播放，强制移除最久未访问的
        String? forceRemove;
        DateTime? forceOldest;
        for (final entry in _controllers.entries) {
          if (forceOldest == null ||
              entry.value.lastAccessedAt.isBefore(forceOldest)) {
            forceOldest = entry.value.lastAccessedAt;
            forceRemove = entry.key;
          }
        }
        if (forceRemove != null) {
          final wrapper = _controllers.remove(forceRemove);
          wrapper?.controller.dispose();
          AppConfig.videoLog('VideoPreloadManager: force evicted controller for $forceRemove');
        }
      }
    }
  }

  /// 获取当前控制器数量
  int get controllerCount => _controllers.length;

  /// 获取预加载中的数量
  int get preloadingCount => _preloading.length;

  /// 获取视频列表
  List<PreloadItem> get videoList => _videoList;

  /// 根据videoId查找视频项
  PreloadItem? findVideo(String videoId) {
    try {
      return _videoList.firstWhere((v) => v.videoId == videoId);
    } catch (_) {
      return null;
    }
  }

  /// 根据videoId查找索引
  int findVideoIndex(String videoId) {
    return _videoList.indexWhere((v) => v.videoId == videoId);
  }

  /// 调试信息
  Map<String, dynamic> get debugInfo => {
        'controllerCount': _controllers.length,
        'preloadingCount': _preloading.length,
        'currentIndex': _currentIndex,
        'videoListSize': _videoList.length,
        'controllers': _controllers.keys.toList(),
      };
}
