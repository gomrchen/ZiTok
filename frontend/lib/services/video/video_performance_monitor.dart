import 'dart:collection';
import 'package:flutter/foundation.dart';

/// 播放事件类型
enum PlaybackEventType {
  loadStart,
  loadComplete,
  loadError,
  playStart,
  playPause,
  playResume,
  playComplete,
  seekStart,
  seekComplete,
  bufferingStart,
  bufferingEnd,
  qualityChange,
  error,
}

/// 播放事件
class PlaybackEvent {
  final PlaybackEventType type;
  final String videoId;
  final DateTime timestamp;
  final Map<String, dynamic>? data;

  PlaybackEvent({
    required this.type,
    required this.videoId,
    DateTime? timestamp,
    this.data,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'videoId': videoId,
        'timestamp': timestamp.toIso8601String(),
        'data': data,
      };
}

/// 视频播放指标
class VideoMetrics {
  final String videoId;
  DateTime? loadStartTime;
  DateTime? loadEndTime;
  DateTime? firstFrameTime;
  int bufferingCount = 0;
  Duration totalBufferingTime = Duration.zero;
  int errorCount = 0;
  String? lastError;
  int seekCount = 0;
  Duration totalWatchTime = Duration.zero;
  DateTime? lastWatchStartTime;

  VideoMetrics({required this.videoId});

  /// 首帧加载时间
  Duration? get timeToFirstFrame {
    if (loadStartTime != null && firstFrameTime != null) {
      return firstFrameTime!.difference(loadStartTime!);
    }
    return null;
  }

  /// 加载时间
  Duration? get loadTime {
    if (loadStartTime != null && loadEndTime != null) {
      return loadEndTime!.difference(loadStartTime!);
    }
    return null;
  }

  /// 卡顿率（缓冲时间/观看时间）
  double get bufferingRate {
    if (totalWatchTime.inMilliseconds > 0) {
      return totalBufferingTime.inMilliseconds / totalWatchTime.inMilliseconds;
    }
    return 0.0;
  }

  Map<String, dynamic> toJson() => {
        'videoId': videoId,
        'timeToFirstFrame': timeToFirstFrame?.inMilliseconds,
        'loadTime': loadTime?.inMilliseconds,
        'bufferingCount': bufferingCount,
        'totalBufferingTimeMs': totalBufferingTime.inMilliseconds,
        'bufferingRate': bufferingRate,
        'errorCount': errorCount,
        'lastError': lastError,
        'seekCount': seekCount,
        'totalWatchTimeMs': totalWatchTime.inMilliseconds,
      };
}

/// 聚合性能指标
class AggregateMetrics {
  int totalVideosPlayed = 0;
  int totalLoadErrors = 0;
  Duration avgTimeToFirstFrame = Duration.zero;
  Duration avgLoadTime = Duration.zero;
  double avgBufferingRate = 0.0;
  int totalBufferingEvents = 0;
  Duration totalWatchTime = Duration.zero;

  final List<Duration> _timeToFirstFrameSamples = [];
  final List<Duration> _loadTimeSamples = [];
  final List<double> _bufferingRateSamples = [];

  void addSample(VideoMetrics metrics) {
    totalVideosPlayed++;

    if (metrics.timeToFirstFrame != null) {
      _timeToFirstFrameSamples.add(metrics.timeToFirstFrame!);
      _updateAvgTimeToFirstFrame();
    }

    if (metrics.loadTime != null) {
      _loadTimeSamples.add(metrics.loadTime!);
      _updateAvgLoadTime();
    }

    if (metrics.totalWatchTime.inMilliseconds > 0) {
      _bufferingRateSamples.add(metrics.bufferingRate);
      _updateAvgBufferingRate();
    }

    totalBufferingEvents += metrics.bufferingCount;
    totalLoadErrors += metrics.errorCount;
    totalWatchTime += metrics.totalWatchTime;
  }

  void _updateAvgTimeToFirstFrame() {
    if (_timeToFirstFrameSamples.isEmpty) return;
    final total = _timeToFirstFrameSamples.fold<int>(0, (sum, d) => sum + d.inMilliseconds);
    avgTimeToFirstFrame = Duration(milliseconds: total ~/ _timeToFirstFrameSamples.length);
  }

  void _updateAvgLoadTime() {
    if (_loadTimeSamples.isEmpty) return;
    final total = _loadTimeSamples.fold<int>(0, (sum, d) => sum + d.inMilliseconds);
    avgLoadTime = Duration(milliseconds: total ~/ _loadTimeSamples.length);
  }

  void _updateAvgBufferingRate() {
    if (_bufferingRateSamples.isEmpty) return;
    final total = _bufferingRateSamples.fold<double>(0, (sum, r) => sum + r);
    avgBufferingRate = total / _bufferingRateSamples.length;
  }

  Map<String, dynamic> toJson() => {
        'totalVideosPlayed': totalVideosPlayed,
        'totalLoadErrors': totalLoadErrors,
        'avgTimeToFirstFrameMs': avgTimeToFirstFrame.inMilliseconds,
        'avgLoadTimeMs': avgLoadTime.inMilliseconds,
        'avgBufferingRate': avgBufferingRate,
        'totalBufferingEvents': totalBufferingEvents,
        'totalWatchTimeMs': totalWatchTime.inMilliseconds,
      };
}

/// 视频性能监控服务
///
/// 功能：
/// - 记录播放事件和指标
/// - 计算首帧时间、卡顿率等关键指标
/// - 聚合统计分析
/// - 支持事件监听
class VideoPerformanceMonitor {
  static VideoPerformanceMonitor? _instance;
  static VideoPerformanceMonitor get instance => _instance ??= VideoPerformanceMonitor._();

  VideoPerformanceMonitor._();

  /// 单个视频的指标
  final Map<String, VideoMetrics> _videoMetrics = {};

  /// 事件历史（有限缓冲）
  final Queue<PlaybackEvent> _eventHistory = Queue();
  static const int _maxEventHistory = 100;

  /// 聚合指标
  final AggregateMetrics _aggregateMetrics = AggregateMetrics();

  /// 事件监听器
  final List<void Function(PlaybackEvent)> _eventListeners = [];

  /// 当前正在缓冲的视频
  final Set<String> _bufferingVideos = {};
  final Map<String, DateTime> _bufferingStartTimes = {};

  /// 记录加载开始
  void recordLoadStart(String videoId) {
    final metrics = _getOrCreateMetrics(videoId);
    metrics.loadStartTime = DateTime.now();
    _emitEvent(PlaybackEvent(type: PlaybackEventType.loadStart, videoId: videoId));
  }

  /// 记录加载完成
  void recordLoadComplete(String videoId, Duration loadTime) {
    final metrics = _getOrCreateMetrics(videoId);
    metrics.loadEndTime = DateTime.now();
    _emitEvent(PlaybackEvent(
      type: PlaybackEventType.loadComplete,
      videoId: videoId,
      data: {'loadTimeMs': loadTime.inMilliseconds},
    ));
  }

  /// 记录加载错误
  void recordLoadError(String videoId, String error) {
    final metrics = _getOrCreateMetrics(videoId);
    metrics.errorCount++;
    metrics.lastError = error;
    _aggregateMetrics.totalLoadErrors++;
    _emitEvent(PlaybackEvent(
      type: PlaybackEventType.loadError,
      videoId: videoId,
      data: {'error': error},
    ));
  }

  /// 记录首帧显示
  void recordFirstFrame(String videoId) {
    final metrics = _getOrCreateMetrics(videoId);
    metrics.firstFrameTime = DateTime.now();

    final ttff = metrics.timeToFirstFrame;
    if (ttff != null) {
      debugPrint('VideoPerformanceMonitor: TTFF for $videoId = ${ttff.inMilliseconds}ms');
    }

    _emitEvent(PlaybackEvent(
      type: PlaybackEventType.playStart,
      videoId: videoId,
      data: {'timeToFirstFrameMs': ttff?.inMilliseconds},
    ));
  }

  /// 记录播放开始
  void recordPlayStart(String videoId) {
    final metrics = _getOrCreateMetrics(videoId);
    metrics.lastWatchStartTime = DateTime.now();
    _emitEvent(PlaybackEvent(type: PlaybackEventType.playStart, videoId: videoId));
  }

  /// 记录播放暂停
  void recordPlayPause(String videoId) {
    final metrics = _getOrCreateMetrics(videoId);
    if (metrics.lastWatchStartTime != null) {
      metrics.totalWatchTime += DateTime.now().difference(metrics.lastWatchStartTime!);
      metrics.lastWatchStartTime = null;
    }
    _emitEvent(PlaybackEvent(type: PlaybackEventType.playPause, videoId: videoId));
  }

  /// 记录播放恢复
  void recordPlayResume(String videoId) {
    final metrics = _getOrCreateMetrics(videoId);
    metrics.lastWatchStartTime = DateTime.now();
    _emitEvent(PlaybackEvent(type: PlaybackEventType.playResume, videoId: videoId));
  }

  /// 记录缓冲开始
  void recordBufferingStart(String videoId) {
    if (!_bufferingVideos.contains(videoId)) {
      _bufferingVideos.add(videoId);
      _bufferingStartTimes[videoId] = DateTime.now();

      final metrics = _getOrCreateMetrics(videoId);
      metrics.bufferingCount++;

      _emitEvent(PlaybackEvent(type: PlaybackEventType.bufferingStart, videoId: videoId));
    }
  }

  /// 记录缓冲结束
  void recordBufferingEnd(String videoId) {
    if (_bufferingVideos.contains(videoId)) {
      _bufferingVideos.remove(videoId);

      final startTime = _bufferingStartTimes.remove(videoId);
      if (startTime != null) {
        final bufferingDuration = DateTime.now().difference(startTime);

        final metrics = _getOrCreateMetrics(videoId);
        metrics.totalBufferingTime += bufferingDuration;

        _emitEvent(PlaybackEvent(
          type: PlaybackEventType.bufferingEnd,
          videoId: videoId,
          data: {'bufferingDurationMs': bufferingDuration.inMilliseconds},
        ));
      }
    }
  }

  /// 记录Seek操作
  void recordSeek(String videoId, Duration from, Duration to) {
    final metrics = _getOrCreateMetrics(videoId);
    metrics.seekCount++;
    _emitEvent(PlaybackEvent(
      type: PlaybackEventType.seekComplete,
      videoId: videoId,
      data: {'fromMs': from.inMilliseconds, 'toMs': to.inMilliseconds},
    ));
  }

  /// 记录播放完成
  void recordPlayComplete(String videoId) {
    final metrics = _getOrCreateMetrics(videoId);
    if (metrics.lastWatchStartTime != null) {
      metrics.totalWatchTime += DateTime.now().difference(metrics.lastWatchStartTime!);
      metrics.lastWatchStartTime = null;
    }

    // 添加到聚合统计
    _aggregateMetrics.addSample(metrics);

    _emitEvent(PlaybackEvent(type: PlaybackEventType.playComplete, videoId: videoId));
    debugPrint('VideoPerformanceMonitor: play complete for $videoId, metrics=${metrics.toJson()}');
  }

  /// 记录错误
  void recordError(String videoId, String error) {
    final metrics = _getOrCreateMetrics(videoId);
    metrics.errorCount++;
    metrics.lastError = error;
    _emitEvent(PlaybackEvent(
      type: PlaybackEventType.error,
      videoId: videoId,
      data: {'error': error},
    ));
  }

  /// 获取视频指标
  VideoMetrics? getMetrics(String videoId) => _videoMetrics[videoId];

  /// 获取聚合指标
  AggregateMetrics get aggregateMetrics => _aggregateMetrics;

  /// 获取事件历史
  List<PlaybackEvent> get eventHistory => _eventHistory.toList();

  /// 添加事件监听器
  void addEventListener(void Function(PlaybackEvent) listener) {
    _eventListeners.add(listener);
  }

  /// 移除事件监听器
  void removeEventListener(void Function(PlaybackEvent) listener) {
    _eventListeners.remove(listener);
  }

  /// 清除所有指标
  void clearMetrics() {
    _videoMetrics.clear();
    _eventHistory.clear();
    _bufferingVideos.clear();
    _bufferingStartTimes.clear();
  }

  /// 导出指标报告
  Map<String, dynamic> exportReport() {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'aggregate': _aggregateMetrics.toJson(),
      'recentVideos': _videoMetrics.values.take(10).map((m) => m.toJson()).toList(),
      'recentEvents': _eventHistory.take(20).map((e) => e.toJson()).toList(),
    };
  }

  VideoMetrics _getOrCreateMetrics(String videoId) {
    return _videoMetrics.putIfAbsent(videoId, () => VideoMetrics(videoId: videoId));
  }

  void _emitEvent(PlaybackEvent event) {
    // 添加到历史
    _eventHistory.addLast(event);
    while (_eventHistory.length > _maxEventHistory) {
      _eventHistory.removeFirst();
    }

    // 通知监听器
    for (final listener in _eventListeners) {
      try {
        listener(event);
      } catch (e) {
        debugPrint('VideoPerformanceMonitor: listener error: $e');
      }
    }
  }

  /// 调试信息
  Map<String, dynamic> get debugInfo => {
        'trackedVideos': _videoMetrics.length,
        'eventHistorySize': _eventHistory.length,
        'activeBuffering': _bufferingVideos.toList(),
        'aggregate': _aggregateMetrics.toJson(),
      };
}
