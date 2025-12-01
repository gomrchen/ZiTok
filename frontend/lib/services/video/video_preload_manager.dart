import 'dart:async';
import 'dart:collection';
import 'package:video_player/video_player.dart';
import 'video_cache_service.dart';
import 'video_performance_monitor.dart';
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
  bool isPreloaded;
  bool isPlaying;

  ControllerWrapper({
    required this.controller,
    required this.videoId,
    required this.createdAt,
    this.isPreloaded = false,
    this.isPlaying = false,
  });

  Duration get age => DateTime.now().difference(createdAt);
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

  /// 初始化管理器
  void init({
    VideoCacheService? cacheService,
    VideoPerformanceMonitor? monitor,
  }) {
    _cacheService = cacheService;
    _monitor = monitor;
    AppConfig.videoLog('VideoPreloadManager: initialized');
  }

  /// 设置视频列表
  void setVideoList(List<PreloadItem> videos) {
    _videoList = videos;
    AppConfig.videoLog('VideoPreloadManager: video list updated, count=${videos.length}');
  }

  /// 更新当前播放索引，触发预加载
  void updateCurrentIndex(int index) {
    if (index == _currentIndex && _controllers.isNotEmpty) return;
    _currentIndex = index;
    _schedulePreload();
  }

  /// 获取或创建视频控制器
  Future<VideoPlayerController?> getController(String videoId, String videoUrl) async {
    // 检查是否已存在
    final existing = _controllers[videoId];
    if (existing != null) {
      // 移到末尾（LRU）
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
      // 移到末尾（LRU）
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

    // 计算需要预加载的索引范围
    final start = (_currentIndex - _config.preloadWindow).clamp(0, _videoList.length - 1);
    final end = (_currentIndex + _config.preloadWindow).clamp(0, _videoList.length - 1);

    // 收集需要预加载的视频
    final toPreload = <PreloadItem>[];
    for (int i = start; i <= end; i++) {
      final item = _videoList[i];
      if (!_controllers.containsKey(item.videoId) && !_preloading.contains(item.videoId)) {
        toPreload.add(item);
      }
    }

    // 按距离当前索引排序（优先加载近的）
    toPreload.sort((a, b) {
      final distA = (a.index - _currentIndex).abs();
      final distB = (b.index - _currentIndex).abs();
      return distA.compareTo(distB);
    });

    // 智能预加载：根据网络状况限制预加载数量
    final preloadCount = _config.smartPreload ? _getSmartPreloadCount() : toPreload.length;
    final limited = toPreload.take(preloadCount);

    AppConfig.videoLog('VideoPreloadManager: preloading ${limited.length} videos around index $_currentIndex');

    // 并行预加载
    await Future.wait(limited.map((item) => _preloadVideo(item)));

    // 清理超出范围的控制器
    _cleanupOldControllers(start, end);
  }

  /// 根据网络状况获取预加载数量
  int _getSmartPreloadCount() {
    // TODO: 接入网络状态检测
    // 默认返回配置的窗口大小
    return _config.preloadWindow * 2 + 1;
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
      if (_cacheService != null) {
        final cachedPath = await _cacheService!.getCachedVideoPath(videoUrl);
        if (cachedPath != null) {
          actualUrl = cachedPath;
          AppConfig.videoLog('VideoPreloadManager: using cached video for $videoId');
        }
      }

      final controller = VideoPlayerController.networkUrl(Uri.parse(actualUrl));
      await controller.initialize();

      final loadTime = DateTime.now().difference(startTime);
      _monitor?.recordLoadComplete(videoId, loadTime);

      final wrapper = ControllerWrapper(
        controller: controller,
        videoId: videoId,
        createdAt: DateTime.now(),
        isPreloaded: isPreload,
      );

      _controllers[videoId] = wrapper;

      AppConfig.videoLog('VideoPreloadManager: created controller for $videoId in ${loadTime.inMilliseconds}ms');
      return controller;
    } catch (e) {
      _monitor?.recordLoadError(videoId, e.toString());
      AppConfig.videoLog('VideoPreloadManager: failed to create controller for $videoId: $e');
      return null;
    }
  }

  /// 确保控制器数量不超过限制
  void _ensureCapacity() {
    while (_controllers.length >= _config.maxControllers) {
      // 找到最早且非播放中的控制器
      String? toRemove;
      for (final entry in _controllers.entries) {
        if (!entry.value.isPlaying) {
          toRemove = entry.key;
          break;
        }
      }

      if (toRemove != null) {
        final wrapper = _controllers.remove(toRemove);
        wrapper?.controller.dispose();
        AppConfig.videoLog('VideoPreloadManager: evicted controller for $toRemove (capacity)');
      } else {
        // 所有控制器都在播放，强制移除最老的
        final oldest = _controllers.entries.first;
        _controllers.remove(oldest.key);
        oldest.value.controller.dispose();
        AppConfig.videoLog('VideoPreloadManager: force evicted controller for ${oldest.key}');
      }
    }
  }

  /// 清理超出预加载范围的控制器
  void _cleanupOldControllers(int start, int end) {
    final validIds = <String>{};
    for (int i = start; i <= end; i++) {
      if (i >= 0 && i < _videoList.length) {
        validIds.add(_videoList[i].videoId);
      }
    }

    final toRemove = <String>[];
    for (final entry in _controllers.entries) {
      if (!validIds.contains(entry.key) && !entry.value.isPlaying) {
        toRemove.add(entry.key);
      }
    }

    for (final id in toRemove) {
      final wrapper = _controllers.remove(id);
      wrapper?.controller.dispose();
      AppConfig.videoLog('VideoPreloadManager: cleaned up controller for $id (out of range)');
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
