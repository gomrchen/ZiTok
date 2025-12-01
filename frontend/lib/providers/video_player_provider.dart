import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../services/video/video_preload_manager.dart';
import '../services/video/video_cache_service.dart';
import '../services/video/video_performance_monitor.dart';
import '../utils/app_config.dart';

/// 播放状态
enum PlaybackState {
  idle,
  loading,
  ready,
  playing,
  paused,
  buffering,
  error,
  completed,
}

/// 缓冲状态
class BufferState {
  final Duration buffered;
  final Duration total;
  final bool isBuffering;

  const BufferState({
    this.buffered = Duration.zero,
    this.total = Duration.zero,
    this.isBuffering = false,
  });

  double get progress => total.inMilliseconds > 0 ? buffered.inMilliseconds / total.inMilliseconds : 0.0;
}

/// 视频播放器状态管理 Provider
///
/// 功能：
/// - 统一管理播放器状态
/// - 集成预加载管理器
/// - 集成缓存服务
/// - 集成性能监控
/// - 页面可见性管理（自动暂停/恢复）
class VideoPlayerProvider extends ChangeNotifier {
  final VideoPreloadManager _preloadManager = VideoPreloadManager.instance;
  final VideoCacheService _cacheService = VideoCacheService.instance;
  final VideoPerformanceMonitor _monitor = VideoPerformanceMonitor.instance;

  VideoPlayerController? _currentController;
  String? _currentVideoId;
  PlaybackState _state = PlaybackState.idle;
  BufferState _bufferState = const BufferState();
  String? _errorMessage;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isAppVisible = true;
  bool _wasPlayingBeforeHide = false;

  // Getters
  VideoPlayerController? get currentController => _currentController;
  String? get currentVideoId => _currentVideoId;
  PlaybackState get state => _state;
  BufferState get bufferState => _bufferState;
  String? get errorMessage => _errorMessage;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get isPlaying => _state == PlaybackState.playing;
  bool get isBuffering => _state == PlaybackState.buffering || _bufferState.isBuffering;
  bool get isAppVisible => _isAppVisible;

  VideoPlayerProvider() {
    _init();
  }

  Future<void> _init() async {
    await _cacheService.init();
    _preloadManager.init(
      cacheService: _cacheService,
      monitor: _monitor,
    );
  }

  /// 设置视频列表用于预加载
  void setVideoList(List<Map<String, String>> videos) {
    final items = videos
        .asMap()
        .entries
        .map((e) => PreloadItem(
              videoId: e.value['id'] ?? '',
              videoUrl: e.value['url'] ?? '',
              index: e.key,
            ))
        .toList();
    _preloadManager.setVideoList(items);
  }

  /// 播放视频
  Future<void> playVideo(String videoId, String videoUrl, {bool autoPlay = true}) async {
    if (_currentVideoId == videoId && _currentController != null) {
      if (autoPlay) {
        await _currentController!.play();
        _state = PlaybackState.playing;
        notifyListeners();
      }
      return;
    }

    // 暂停当前视频
    await pause();

    _currentVideoId = videoId;
    _state = PlaybackState.loading;
    _errorMessage = null;
    notifyListeners();

    _monitor.recordLoadStart(videoId);

    try {
      // 尝试获取预加载的控制器，或创建新的
      var controller = _preloadManager.getPreloadedController(videoId);
      controller ??= await _preloadManager.getController(videoId, videoUrl);

      if (controller == null) {
        throw Exception('无法创建视频控制器');
      }

      _currentController = controller;

      // 监听控制器状态
      _setupControllerListeners(controller, videoId);

      _duration = controller.value.duration;
      _state = PlaybackState.ready;

      _monitor.recordFirstFrame(videoId);

      if (autoPlay) {
        await controller.play();
        _state = PlaybackState.playing;
        _monitor.recordPlayStart(videoId);
        _preloadManager.markAsPlaying(videoId);
      }

      notifyListeners();

      // 触发预加载周围视频
      final currentIndex = _preloadManager.findVideoIndex(videoId);
      if (currentIndex >= 0) {
        _preloadManager.updateCurrentIndex(currentIndex);
      }
    } catch (e) {
      _state = PlaybackState.error;
      _errorMessage = e.toString();
      _monitor.recordLoadError(videoId, e.toString());
      notifyListeners();
    }
  }

  /// 设置控制器监听
  void _setupControllerListeners(VideoPlayerController controller, String videoId) {
    controller.addListener(() {
      if (!controller.value.isInitialized) return;

      // 更新位置
      _position = controller.value.position;
      _duration = controller.value.duration;

      // 更新缓冲状态
      final buffered = controller.value.buffered;
      final bufferedDuration = buffered.isNotEmpty ? buffered.last.end : Duration.zero;
      final wasBuffering = _bufferState.isBuffering;
      final isBufferingNow = controller.value.isBuffering;

      _bufferState = BufferState(
        buffered: bufferedDuration,
        total: _duration,
        isBuffering: isBufferingNow,
      );

      // 记录缓冲事件
      if (isBufferingNow && !wasBuffering) {
        _monitor.recordBufferingStart(videoId);
        _state = PlaybackState.buffering;
      } else if (!isBufferingNow && wasBuffering) {
        _monitor.recordBufferingEnd(videoId);
        if (controller.value.isPlaying) {
          _state = PlaybackState.playing;
        }
      }

      // 检查播放状态
      if (controller.value.isPlaying && _state != PlaybackState.playing && !isBufferingNow) {
        _state = PlaybackState.playing;
      } else if (!controller.value.isPlaying && _state == PlaybackState.playing) {
        _state = PlaybackState.paused;
      }

      // 检查播放完成
      if (_position >= _duration && _duration.inMilliseconds > 0) {
        _state = PlaybackState.completed;
        _monitor.recordPlayComplete(videoId);
      }

      notifyListeners();
    });
  }

  /// 暂停播放
  Future<void> pause() async {
    if (_currentController != null && _currentController!.value.isPlaying) {
      await _currentController!.pause();
      _state = PlaybackState.paused;
      if (_currentVideoId != null) {
        _monitor.recordPlayPause(_currentVideoId!);
        _preloadManager.markAsStopped(_currentVideoId!);
      }
      notifyListeners();
    }
  }

  /// 恢复播放
  Future<void> resume() async {
    if (_currentController != null && !_currentController!.value.isPlaying) {
      await _currentController!.play();
      _state = PlaybackState.playing;
      if (_currentVideoId != null) {
        _monitor.recordPlayResume(_currentVideoId!);
        _preloadManager.markAsPlaying(_currentVideoId!);
      }
      notifyListeners();
    }
  }

  /// 切换播放/暂停
  Future<void> togglePlayPause() async {
    if (_currentController?.value.isPlaying ?? false) {
      await pause();
    } else {
      await resume();
    }
  }

  /// 跳转到指定位置
  Future<void> seekTo(Duration position) async {
    if (_currentController != null) {
      final from = _position;
      await _currentController!.seekTo(position);
      _position = position;
      if (_currentVideoId != null) {
        _monitor.recordSeek(_currentVideoId!, from, position);
      }
      notifyListeners();
    }
  }

  /// 设置循环播放
  Future<void> setLooping(bool looping) async {
    await _currentController?.setLooping(looping);
  }

  /// 设置音量
  Future<void> setVolume(double volume) async {
    await _currentController?.setVolume(volume.clamp(0.0, 1.0));
  }

  /// 处理应用可见性变化
  void onAppVisibilityChanged(bool isVisible) {
    _isAppVisible = isVisible;

    if (!isVisible) {
      // 应用进入后台，暂停播放
      if (_currentController?.value.isPlaying ?? false) {
        _wasPlayingBeforeHide = true;
        pause();
        AppConfig.videoLog('VideoPlayerProvider: paused due to app hidden');
      } else {
        _wasPlayingBeforeHide = false;
      }
      // 暂停所有预加载的视频
      _preloadManager.pauseAll();
    } else {
      // 应用回到前台，恢复播放
      if (_wasPlayingBeforeHide) {
        resume();
        AppConfig.videoLog('VideoPlayerProvider: resumed due to app visible');
      }
    }
  }

  /// 处理页面可见性变化（用于 TabBar 切换等）
  void onPageVisibilityChanged(bool isVisible, {String? videoId}) {
    if (videoId != null && videoId != _currentVideoId) return;

    if (!isVisible) {
      if (_currentController?.value.isPlaying ?? false) {
        _wasPlayingBeforeHide = true;
        pause();
        AppConfig.videoLog('VideoPlayerProvider: paused due to page hidden');
      } else {
        _wasPlayingBeforeHide = false;
      }
    } else {
      if (_wasPlayingBeforeHide) {
        resume();
        AppConfig.videoLog('VideoPlayerProvider: resumed due to page visible');
      }
    }
  }

  /// 停止当前视频并释放
  void stopCurrent() {
    if (_currentVideoId != null) {
      _preloadManager.markAsStopped(_currentVideoId!);
      _monitor.recordPlayComplete(_currentVideoId!);
    }
    _currentController = null;
    _currentVideoId = null;
    _state = PlaybackState.idle;
    _position = Duration.zero;
    _duration = Duration.zero;
    _errorMessage = null;
    notifyListeners();
  }

  /// 重试加载
  Future<void> retry() async {
    if (_currentVideoId != null) {
      final videoId = _currentVideoId!;
      final video = _preloadManager.findVideo(videoId);
      if (video == null) return;

      // 释放当前控制器
      _preloadManager.releaseController(videoId);

      // 重新加载
      await playVideo(videoId, video.videoUrl);
    }
  }

  /// 获取性能报告
  Map<String, dynamic> getPerformanceReport() {
    return _monitor.exportReport();
  }

  /// 获取缓存信息
  Map<String, dynamic> getCacheInfo() {
    return _cacheService.debugInfo;
  }

  /// 清除缓存
  Future<void> clearCache() async {
    await _cacheService.clearAll();
  }

  @override
  void dispose() {
    _preloadManager.releaseAll();
    super.dispose();
  }
}
