import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../utils/app_config.dart';

/// 视频页面类型
enum VideoPageType {
  recommend,  // 推荐页全屏播放
  detail,     // 视频详情页
}

/// 视频页面上下文信息
class VideoPageContext {
  final String videoId;
  final VideoPageType pageType;
  final VideoPlayerController controller;

  VideoPageContext({
    required this.videoId,
    required this.pageType,
    required this.controller,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoPageContext &&
          videoId == other.videoId &&
          pageType == other.pageType;

  @override
  int get hashCode => videoId.hashCode ^ pageType.hashCode;
}

/// 全局视频播放状态管理器
///
/// 核心职责：
/// 1. 确保同一时间只有一个视频在播放
/// 2. 跟踪当前活跃的视频页面
/// 3. 当离开视频页面时自动暂停视频
class VideoPlaybackManager {
  VideoPlaybackManager._();
  static final VideoPlaybackManager instance = VideoPlaybackManager._();

  /// 当前活跃的视频页面上下文栈
  final List<VideoPageContext> _pageStack = [];

  /// 当前正在播放的控制器
  VideoPlayerController? _currentPlaying;

  /// 所有注册的控制器（用于全局暂停）
  final Set<VideoPlayerController> _allControllers = {};

  /// 当前活跃的视频页面上下文
  VideoPageContext? get currentPage => _pageStack.isNotEmpty ? _pageStack.last : null;

  /// 进入视频页面时调用
  ///
  /// [videoId] 视频ID
  /// [pageType] 页面类型
  /// [controller] 视频控制器
  void enterVideoPage({
    required String videoId,
    required VideoPageType pageType,
    required VideoPlayerController controller,
  }) {
    final context = VideoPageContext(
      videoId: videoId,
      pageType: pageType,
      controller: controller,
    );

    // 暂停当前播放的视频（如果不同）
    if (_currentPlaying != null && _currentPlaying != controller) {
      _currentPlaying!.pause();
      AppConfig.log('VideoPlaybackManager: 暂停上一个视频');
    }

    _pageStack.add(context);
    _allControllers.add(controller);
    _currentPlaying = controller;

    AppConfig.log('VideoPlaybackManager: 进入视频页面 videoId=$videoId, type=$pageType, 栈深度=${_pageStack.length}');
  }

  /// 离开视频页面时调用
  void leaveVideoPage(VideoPlayerController controller) {
    // 从栈中移除该控制器对应的上下文
    _pageStack.removeWhere((ctx) => ctx.controller == controller);
    _allControllers.remove(controller);

    // 暂停该控制器
    if (controller.value.isPlaying) {
      controller.pause();
    }

    // 如果是当前播放的控制器，清除引用
    if (_currentPlaying == controller) {
      _currentPlaying = null;
    }

    AppConfig.log('VideoPlaybackManager: 离开视频页面, 栈深度=${_pageStack.length}');
  }

  /// 标记某个控制器开始播放
  /// 会自动暂停其他正在播放的视频
  void markAsPlaying(VideoPlayerController controller) {
    if (_currentPlaying != null && _currentPlaying != controller) {
      _currentPlaying!.pause();
      AppConfig.log('VideoPlaybackManager: 切换播放，暂停上一个');
    }
    _currentPlaying = controller;
  }

  /// 注册控制器（不进入页面栈，仅用于全局管理）
  void register(VideoPlayerController controller) {
    _allControllers.add(controller);
  }

  /// 注销控制器
  void unregister(VideoPlayerController controller) {
    _allControllers.remove(controller);
    _pageStack.removeWhere((ctx) => ctx.controller == controller);
    if (_currentPlaying == controller) {
      _currentPlaying = null;
    }
  }

  /// 暂停当前播放的视频
  void pauseCurrent() {
    if (_currentPlaying != null && _currentPlaying!.value.isPlaying) {
      _currentPlaying!.pause();
      AppConfig.log('VideoPlaybackManager: 暂停当前视频');
    }
  }

  /// 暂停所有注册的视频
  void pauseAll() {
    for (final c in _allControllers) {
      if (c.value.isPlaying) {
        c.pause();
      }
    }
    _currentPlaying = null;
    AppConfig.log('VideoPlaybackManager: 暂停所有视频');
  }

  /// 当页面被覆盖时调用（有新页面push到当前页面上方）
  void onPageCovered() {
    pauseCurrent();
    AppConfig.log('VideoPlaybackManager: 页面被覆盖，暂停视频');
  }

  /// 当页面重新可见时调用（上方页面pop）
  void onPageRevealed(VideoPlayerController? controller) {
    // 可选：自动恢复播放
    // 这里不自动恢复，让用户手动点击播放
    AppConfig.log('VideoPlaybackManager: 页面重新可见');
  }

  /// 检查是否有视频正在播放
  bool get isAnyPlaying => _currentPlaying?.value.isPlaying ?? false;

  /// 获取当前播放的控制器
  VideoPlayerController? get currentController => _currentPlaying;
}

/// 视频页面路由观察者
///
/// 用于监听路由变化，当离开视频页面时自动暂停视频
class VideoRouteObserver extends NavigatorObserver {
  static final VideoRouteObserver instance = VideoRouteObserver._();
  VideoRouteObserver._();

  /// 判断路由是否是视频相关页面
  bool _isVideoRoute(Route? route) {
    if (route == null) return false;

    final name = route.settings.name;
    if (name == null) {
      // 如果没有名称，检查页面类型
      // 这里无法准确判断，返回false保守处理
      return false;
    }

    return name.startsWith('/video/') ||
           name == '/home' ||
           name.startsWith('/home');
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);

    // 如果从视频页面跳转到非视频页面，暂停视频
    if (_isVideoRoute(previousRoute) && !_isVideoRoute(route)) {
      VideoPlaybackManager.instance.pauseAll();
      AppConfig.log('VideoRouteObserver: didPush 离开视频页面，暂停所有视频');
    }

    // 即使是视频页面之间跳转，也暂停当前视频（新页面会启动新的视频）
    if (_isVideoRoute(previousRoute) && _isVideoRoute(route)) {
      VideoPlaybackManager.instance.pauseCurrent();
      AppConfig.log('VideoRouteObserver: didPush 视频页面间跳转，暂停当前视频');
    }
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);

    // 如果从视频页面返回到非视频页面，暂停视频
    if (_isVideoRoute(route) && !_isVideoRoute(previousRoute)) {
      VideoPlaybackManager.instance.pauseAll();
      AppConfig.log('VideoRouteObserver: didPop 离开视频页面，暂停所有视频');
    }
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);

    if (_isVideoRoute(oldRoute) && !_isVideoRoute(newRoute)) {
      VideoPlaybackManager.instance.pauseAll();
      AppConfig.log('VideoRouteObserver: didReplace 离开视频页面，暂停所有视频');
    }
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    super.didRemove(route, previousRoute);

    if (_isVideoRoute(route)) {
      VideoPlaybackManager.instance.pauseAll();
      AppConfig.log('VideoRouteObserver: didRemove 视频页面被移除，暂停所有视频');
    }
  }
}

/// RouteAware 混入，用于视频页面检测可见性变化
///
/// 使用方式：
/// 1. 在视频页面 State 中混入此 mixin
/// 2. 在 didChangeDependencies 中订阅 routeObserver
/// 3. 在 dispose 中取消订阅
mixin VideoPageVisibilityMixin<T extends StatefulWidget> on State<T> {
  /// 子类需要提供：获取当前视频控制器
  VideoPlayerController? get videoController;

  /// 页面被覆盖时调用（有新页面push到当前页面上方）
  @mustCallSuper
  void onVideoCovered() {
    VideoPlaybackManager.instance.onPageCovered();
  }

  /// 页面重新可见时调用（上方页面pop）
  @mustCallSuper
  void onVideoRevealed() {
    VideoPlaybackManager.instance.onPageRevealed(videoController);
  }
}
