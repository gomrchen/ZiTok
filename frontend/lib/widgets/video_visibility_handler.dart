import 'package:flutter/material.dart';

/// 应用生命周期观察者
///
/// 用于监听应用的前后台切换，自动暂停/恢复视频播放
class AppLifecycleObserver extends WidgetsBindingObserver {
  final void Function(bool isVisible) onVisibilityChanged;

  AppLifecycleObserver({required this.onVisibilityChanged});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        onVisibilityChanged(true);
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        onVisibilityChanged(false);
        break;
    }
  }
}

/// 页面可见性监听器 Mixin
///
/// 用于监听页面是否在视图中（用于 TabBar、PageView 等场景）
mixin PageVisibilityMixin<T extends StatefulWidget> on State<T> {
  bool _isPageVisible = true;

  bool get isPageVisible => _isPageVisible;

  /// 子类实现此方法处理可见性变化
  void onPageVisibilityChanged(bool isVisible);

  /// 手动设置页面可见性（用于 TabBar 等场景）
  void setPageVisibility(bool isVisible) {
    if (_isPageVisible != isVisible) {
      _isPageVisible = isVisible;
      onPageVisibilityChanged(isVisible);
    }
  }
}

/// 路由感知的页面可见性监听器 Mixin
///
/// 自动监听路由变化（push/pop）来判断页面可见性
mixin RouteAwarePageVisibilityMixin<T extends StatefulWidget> on State<T> implements RouteAware {
  RouteObserver<ModalRoute<void>>? _routeObserver;
  bool _isCurrentRoute = true;

  bool get isCurrentRoute => _isCurrentRoute;

  /// 子类实现此方法处理路由可见性变化
  void onRouteVisibilityChanged(bool isVisible);

  /// 在 didChangeDependencies 中调用此方法注册路由监听
  void subscribeRouteAware(RouteObserver<ModalRoute<void>> routeObserver) {
    _routeObserver = routeObserver;
    _routeObserver?.subscribe(this, ModalRoute.of(context)!);
  }

  /// 在 dispose 中调用此方法取消注册
  void unsubscribeRouteAware() {
    _routeObserver?.unsubscribe(this);
  }

  @override
  void didPush() {
    // 当前路由被推入
    _isCurrentRoute = true;
    onRouteVisibilityChanged(true);
  }

  @override
  void didPopNext() {
    // 上层路由被弹出，当前路由重新可见
    _isCurrentRoute = true;
    onRouteVisibilityChanged(true);
  }

  @override
  void didPop() {
    // 当前路由被弹出
    _isCurrentRoute = false;
    onRouteVisibilityChanged(false);
  }

  @override
  void didPushNext() {
    // 新路由被推入，当前路由不可见
    _isCurrentRoute = false;
    onRouteVisibilityChanged(false);
  }
}

/// 可见性感知的 Widget 包装器
///
/// 自动监听 Widget 在视口中的可见性
class VisibilityAwareWidget extends StatefulWidget {
  final Widget child;
  final void Function(bool isVisible) onVisibilityChanged;
  final double visibilityThreshold;

  const VisibilityAwareWidget({
    super.key,
    required this.child,
    required this.onVisibilityChanged,
    this.visibilityThreshold = 0.5,
  });

  @override
  State<VisibilityAwareWidget> createState() => _VisibilityAwareWidgetState();
}

class _VisibilityAwareWidgetState extends State<VisibilityAwareWidget> {
  final GlobalKey _key = GlobalKey();
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisibility());
  }

  void _checkVisibility() {
    if (!mounted) return;

    final renderObject = _key.currentContext?.findRenderObject();
    if (renderObject is RenderBox) {
      final size = renderObject.size;
      final offset = renderObject.localToGlobal(Offset.zero);
      final screenSize = MediaQuery.of(context).size;

      // 计算可见区域
      final visibleTop = offset.dy.clamp(0.0, screenSize.height);
      final visibleBottom = (offset.dy + size.height).clamp(0.0, screenSize.height);
      final visibleHeight = visibleBottom - visibleTop;
      final visibilityRatio = visibleHeight / size.height;

      final isNowVisible = visibilityRatio >= widget.visibilityThreshold;

      if (isNowVisible != _isVisible) {
        _isVisible = isNowVisible;
        widget.onVisibilityChanged(_isVisible);
      }
    }

    // 继续监听
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisibility());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: _key,
      child: widget.child,
    );
  }
}

/// 视频播放器可见性包装器
///
/// 专门用于视频播放器的可见性管理
/// 当视频不在视口中时自动暂停，重新可见时恢复
class VideoVisibilityWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onBecameVisible;
  final VoidCallback onBecameHidden;
  final double visibilityThreshold;
  final bool pauseWhenHidden;

  const VideoVisibilityWrapper({
    super.key,
    required this.child,
    required this.onBecameVisible,
    required this.onBecameHidden,
    this.visibilityThreshold = 0.3,
    this.pauseWhenHidden = true,
  });

  @override
  State<VideoVisibilityWrapper> createState() => _VideoVisibilityWrapperState();
}

class _VideoVisibilityWrapperState extends State<VideoVisibilityWrapper>
    with WidgetsBindingObserver {
  bool _isVisible = true;
  bool _isAppVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasAppVisible = _isAppVisible;
    _isAppVisible = state == AppLifecycleState.resumed;

    if (_isAppVisible != wasAppVisible) {
      _updateVisibility();
    }
  }

  void _onWidgetVisibilityChanged(bool isVisible) {
    if (_isVisible != isVisible) {
      _isVisible = isVisible;
      _updateVisibility();
    }
  }

  void _updateVisibility() {
    final isEffectivelyVisible = _isVisible && _isAppVisible;

    if (isEffectivelyVisible) {
      widget.onBecameVisible();
    } else if (widget.pauseWhenHidden) {
      widget.onBecameHidden();
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityAwareWidget(
      visibilityThreshold: widget.visibilityThreshold,
      onVisibilityChanged: _onWidgetVisibilityChanged,
      child: widget.child,
    );
  }
}

/// 全局路由观察者
///
/// 用于追踪路由变化，供需要路由感知的组件使用
class VideoRouteObserver extends RouteObserver<ModalRoute<void>> {
  static final VideoRouteObserver instance = VideoRouteObserver._();

  VideoRouteObserver._();

  final List<void Function(Route<dynamic>?, Route<dynamic>?)> _listeners = [];

  void addRouteChangeListener(void Function(Route<dynamic>?, Route<dynamic>?) listener) {
    _listeners.add(listener);
  }

  void removeRouteChangeListener(void Function(Route<dynamic>?, Route<dynamic>?) listener) {
    _listeners.remove(listener);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    for (final listener in _listeners) {
      listener(route, previousRoute);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    for (final listener in _listeners) {
      listener(previousRoute, route);
    }
  }
}
