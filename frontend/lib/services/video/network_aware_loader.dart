import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../utils/app_config.dart';

/// 网络质量等级
enum NetworkQuality {
  /// 极差（<500KB/s）- 仅加载当前视频
  veryPoor,
  /// 差（500KB-1MB/s）- 预加载1个
  poor,
  /// 一般（1-3MB/s）- 预加载2个
  moderate,
  /// 良好（>3MB/s）- 预加载3个
  good,
  /// 未知
  unknown,
}

/// 网络类型
enum NetworkType {
  wifi,
  mobile,
  none,
  unknown,
}

/// 网络状态信息
class NetworkStatus {
  final NetworkType type;
  final NetworkQuality quality;
  final double estimatedSpeedKBps; // 估算速度 KB/s
  final DateTime measuredAt;

  const NetworkStatus({
    required this.type,
    required this.quality,
    required this.estimatedSpeedKBps,
    required this.measuredAt,
  });

  /// 获取推荐的预加载数量
  int get recommendedPreloadCount {
    switch (quality) {
      case NetworkQuality.veryPoor:
        return 0; // 不预加载，专注当前视频
      case NetworkQuality.poor:
        return 1;
      case NetworkQuality.moderate:
        return 2;
      case NetworkQuality.good:
        return 3;
      case NetworkQuality.unknown:
        return 1; // 保守策略
    }
  }

  /// 获取推荐的缓冲时间（秒）
  int get recommendedBufferSeconds {
    switch (quality) {
      case NetworkQuality.veryPoor:
        return 3; // 快速启播
      case NetworkQuality.poor:
        return 5;
      case NetworkQuality.moderate:
        return 8;
      case NetworkQuality.good:
        return 10;
      case NetworkQuality.unknown:
        return 5;
    }
  }

  /// 是否应该暂停预加载（专注当前视频）
  bool get shouldPausePreload => quality == NetworkQuality.veryPoor;

  @override
  String toString() => 'NetworkStatus(type: $type, quality: $quality, speed: ${estimatedSpeedKBps.toStringAsFixed(1)}KB/s)';
}

/// 网络感知加载管理器
///
/// 功能：
/// - 检测网络类型（WiFi/移动网络）
/// - 测量网络速度
/// - 动态调整加载策略
/// - 优先级队列管理
class NetworkAwareLoader {
  static NetworkAwareLoader? _instance;
  static NetworkAwareLoader get instance => _instance ??= NetworkAwareLoader._();

  NetworkAwareLoader._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  NetworkStatus _currentStatus = NetworkStatus(
    type: NetworkType.unknown,
    quality: NetworkQuality.unknown,
    estimatedSpeedKBps: 0,
    measuredAt: DateTime.now(),
  );

  /// 速度测量历史（用于平滑估算）
  final List<double> _speedHistory = [];
  static const int _maxSpeedHistory = 5;

  /// 加载优先级队列
  final Map<String, int> _loadPriority = {}; // videoId -> priority (0最高)

  /// 网络状态变化回调
  final List<void Function(NetworkStatus)> _listeners = [];

  /// 获取当前网络状态
  NetworkStatus get currentStatus => _currentStatus;

  /// 初始化
  Future<void> init() async {
    // 监听网络变化
    _subscription = _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);

    // 获取初始网络状态
    await _checkNetworkType();

    AppConfig.videoLog('NetworkAwareLoader: initialized, status=$_currentStatus');
  }

  /// 释放资源
  void dispose() {
    _subscription?.cancel();
    _listeners.clear();
  }

  /// 添加状态变化监听器
  void addListener(void Function(NetworkStatus) listener) {
    _listeners.add(listener);
  }

  /// 移除监听器
  void removeListener(void Function(NetworkStatus) listener) {
    _listeners.remove(listener);
  }

  /// 网络变化处理
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    _checkNetworkType();
  }

  /// 检查网络类型
  Future<void> _checkNetworkType() async {
    try {
      final results = await _connectivity.checkConnectivity();
      NetworkType type = NetworkType.unknown;

      if (results.contains(ConnectivityResult.wifi)) {
        type = NetworkType.wifi;
      } else if (results.contains(ConnectivityResult.mobile)) {
        type = NetworkType.mobile;
      } else if (results.contains(ConnectivityResult.none)) {
        type = NetworkType.none;
      }

      _updateStatus(type: type);
    } catch (e) {
      AppConfig.videoLog('NetworkAwareLoader: check network type failed: $e');
    }
  }

  /// 记录下载速度样本
  /// 在视频加载完成后调用，用于估算网络速度
  void recordSpeedSample(int bytesDownloaded, Duration duration) {
    if (duration.inMilliseconds <= 0) return;

    final speedKBps = bytesDownloaded / duration.inMilliseconds * 1000 / 1024;

    _speedHistory.add(speedKBps);
    if (_speedHistory.length > _maxSpeedHistory) {
      _speedHistory.removeAt(0);
    }

    // 计算平均速度
    final avgSpeed = _speedHistory.reduce((a, b) => a + b) / _speedHistory.length;

    _updateStatus(estimatedSpeed: avgSpeed);
    AppConfig.videoLog('NetworkAwareLoader: speed sample ${speedKBps.toStringAsFixed(1)}KB/s, avg=${avgSpeed.toStringAsFixed(1)}KB/s');
  }

  /// 更新网络状态
  void _updateStatus({NetworkType? type, double? estimatedSpeed}) {
    final newType = type ?? _currentStatus.type;
    final newSpeed = estimatedSpeed ?? _currentStatus.estimatedSpeedKBps;
    final newQuality = _calculateQuality(newType, newSpeed);

    final newStatus = NetworkStatus(
      type: newType,
      quality: newQuality,
      estimatedSpeedKBps: newSpeed,
      measuredAt: DateTime.now(),
    );

    if (newStatus.quality != _currentStatus.quality || newStatus.type != _currentStatus.type) {
      _currentStatus = newStatus;
      _notifyListeners();
      AppConfig.videoLog('NetworkAwareLoader: status updated to $newStatus');
    } else {
      _currentStatus = newStatus;
    }
  }

  /// 计算网络质量等级
  NetworkQuality _calculateQuality(NetworkType type, double speedKBps) {
    // 无网络
    if (type == NetworkType.none) {
      return NetworkQuality.veryPoor;
    }

    // 未测量速度时，根据网络类型估算
    if (speedKBps <= 0) {
      return type == NetworkType.wifi ? NetworkQuality.moderate : NetworkQuality.poor;
    }

    // 根据速度判断（单位：KB/s）
    // 3M带宽 ≈ 375KB/s 理论值，实际约 300KB/s
    if (speedKBps < 200) {
      return NetworkQuality.veryPoor;
    } else if (speedKBps < 500) {
      return NetworkQuality.poor;
    } else if (speedKBps < 1500) {
      return NetworkQuality.moderate;
    } else {
      return NetworkQuality.good;
    }
  }

  /// 通知监听器
  void _notifyListeners() {
    for (final listener in _listeners) {
      listener(_currentStatus);
    }
  }

  // ==================== 优先级管理 ====================

  /// 设置视频加载优先级
  /// priority: 0 = 最高（当前播放），1 = 高（下一个），2+ = 一般
  void setPriority(String videoId, int priority) {
    _loadPriority[videoId] = priority;
  }

  /// 清除优先级
  void clearPriority(String videoId) {
    _loadPriority.remove(videoId);
  }

  /// 获取优先级
  int getPriority(String videoId) {
    return _loadPriority[videoId] ?? 999;
  }

  /// 判断是否应该加载该视频
  /// 低带宽时，只允许加载高优先级视频
  bool shouldLoad(String videoId) {
    final priority = getPriority(videoId);

    // 当前视频总是允许加载
    if (priority == 0) return true;

    // 网络极差时，不预加载
    if (_currentStatus.shouldPausePreload && priority > 0) {
      return false;
    }

    // 根据网络质量限制预加载数量
    final maxPreload = _currentStatus.recommendedPreloadCount;
    return priority <= maxPreload;
  }

  /// 判断是否应该取消加载（被更高优先级任务抢占）
  bool shouldCancelFor(String currentVideoId, String higherPriorityId) {
    final currentPriority = getPriority(currentVideoId);
    final higherPriority = getPriority(higherPriorityId);

    // 网络差时，低优先级任务应该让步
    if (_currentStatus.quality == NetworkQuality.veryPoor ||
        _currentStatus.quality == NetworkQuality.poor) {
      return higherPriority < currentPriority;
    }

    return false;
  }

  // ==================== 加载建议 ====================

  /// 获取当前应该预加载的视频数量
  int getRecommendedPreloadCount() {
    return _currentStatus.recommendedPreloadCount;
  }

  /// 获取推荐的缓冲策略
  Duration getRecommendedBufferDuration() {
    return Duration(seconds: _currentStatus.recommendedBufferSeconds);
  }

  /// 是否建议使用低质量模式
  bool get shouldUseLowQuality {
    return _currentStatus.quality == NetworkQuality.veryPoor ||
           _currentStatus.quality == NetworkQuality.poor;
  }

  /// 调试信息
  Map<String, dynamic> get debugInfo => {
    'networkType': _currentStatus.type.toString(),
    'networkQuality': _currentStatus.quality.toString(),
    'estimatedSpeed': '${_currentStatus.estimatedSpeedKBps.toStringAsFixed(1)}KB/s',
    'recommendedPreload': _currentStatus.recommendedPreloadCount,
    'speedSamples': _speedHistory.length,
    'priorities': _loadPriority,
  };
}
