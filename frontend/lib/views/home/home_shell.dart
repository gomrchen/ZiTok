import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../drama/drama_player_page.dart';
import '../drama/player_overlay.dart';
import '../drama/theater_page.dart';
import '../messages/messages_page.dart';
import '../profile/profile_page.dart';
import '../../services/video/video_preload_manager.dart';
import '../../services/video_playback_manager.dart';
import '../../app.dart';
import 'shell_surface.dart';

/// 短剧主壳：首页连播 / 剧场 / 消息 / 我的
/// 底栏为贴底浮动胶囊，视频真正铺满
class HomeShell extends StatefulWidget {
  final int initialTab;
  const HomeShell({super.key, this.initialTab = 0});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index;
  final VideoPreloadManager _preloadManager = VideoPreloadManager.instance;
  bool _isRefreshingToken = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialTab.clamp(0, 3);
    AppBootstrap.userSession.onAuthenticationFailed = _handleAuthenticationFailed;
    _refreshTokenInBackground();
  }

  @override
  void dispose() {
    AppBootstrap.userSession.onAuthenticationFailed = null;
    super.dispose();
  }

  Future<void> _refreshTokenInBackground() async {
    if (_isRefreshingToken) return;
    _isRefreshingToken = true;
    try {
      final success = await AppBootstrap.refreshTokenIfNeeded();
      if (!success && mounted) _handleAuthenticationFailed();
    } finally {
      _isRefreshingToken = false;
    }
  }

  void _handleAuthenticationFailed() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('登录已失效，请重新登录'),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) context.go('/auth/login');
    });
  }

  void _onTabChanged(int newIndex) {
    final oldIndex = _index;
    setState(() => _index = newIndex);
    if (oldIndex == 0 && newIndex != 0) {
      _preloadManager.pauseAll();
      VideoPlaybackManager.instance.pauseAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final immersive = _index == 0;
    // 贴系统手势区：几乎贴底，只留 2～4px 呼吸
    final dockBottom = bottom > 0 ? 2.0 : 6.0;

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        if (_index != 0) _onTabChanged(0);
      },
      child: Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        backgroundColor: immersive ? Colors.black : ShellSurface.canvas,
        body: Stack(
          fit: StackFit.expand,
          children: [
            IndexedStack(
              index: _index,
              sizing: StackFit.expand,
              children: [
                const DramaPlayerPage(),
                _DockSafePad(bottom: bottom, child: const TheaterPage()),
                _DockSafePad(bottom: bottom, child: const MessagesPage()),
                _DockSafePad(bottom: bottom, child: const ProfilePage()),
              ],
            ),
            Positioned(
              left: 22,
              right: 22,
              bottom: dockBottom + (bottom > 0 ? bottom * 0.15 : 0),
              child: _CapsuleDock(
                index: _index,
                immersive: immersive,
                onChanged: _onTabChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DockSafePad extends StatelessWidget {
  final double bottom;
  final Widget child;
  const _DockSafePad({required this.bottom, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottom + kHomeBottomBarHeight),
      child: child,
    );
  }
}

/// 浮动胶囊坞：无选中背板，图标抖动点亮
class _CapsuleDock extends StatelessWidget {
  final int index;
  final bool immersive;
  final ValueChanged<int> onChanged;

  const _CapsuleDock({
    required this.index,
    required this.immersive,
    required this.onChanged,
  });

  static const _labels = ['首页', '剧场', '消息', '我的'];

  @override
  Widget build(BuildContext context) {
    final glass = immersive
        ? Colors.black.withValues(alpha: 0.42)
        : ShellSurface.card.withValues(alpha: 0.92);
    final border = immersive
        ? Colors.white.withValues(alpha: 0.12)
        : ShellSurface.line;

    return Semantics(
      container: true,
      label: '主导航',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: glass,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: border, width: 0.8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: immersive ? 0.32 : 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
              gradient: immersive
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.08),
                        Colors.black.withValues(alpha: 0.28),
                      ],
                    )
                  : LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        ShellSurface.card.withValues(alpha: 0.98),
                        ShellSurface.canvas.withValues(alpha: 0.92),
                      ],
                    ),
            ),
            child: SizedBox(
              height: 54,
              child: Row(
                children: List.generate(_labels.length, (i) {
                  return Expanded(
                    child: _DockTab(
                      label: _labels[i],
                      kind: _DockGlyphKind.values[i],
                      selected: i == index,
                      immersive: immersive,
                      onTap: () => onChanged(i),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockTab extends StatefulWidget {
  final String label;
  final _DockGlyphKind kind;
  final bool selected;
  final bool immersive;
  final VoidCallback onTap;

  const _DockTab({
    required this.label,
    required this.kind,
    required this.selected,
    required this.immersive,
    required this.onTap,
  });

  @override
  State<_DockTab> createState() => _DockTabState();
}

class _DockTabState extends State<_DockTab> with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );

  late final Animation<double> _angle = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.22), weight: 14),
    TweenSequenceItem(tween: Tween(begin: -0.22, end: 0.20), weight: 18),
    TweenSequenceItem(tween: Tween(begin: 0.20, end: -0.14), weight: 16),
    TweenSequenceItem(tween: Tween(begin: -0.14, end: 0.08), weight: 16),
    TweenSequenceItem(tween: Tween(begin: 0.08, end: -0.03), weight: 14),
    TweenSequenceItem(tween: Tween(begin: -0.03, end: 0.0), weight: 22),
  ]).animate(CurvedAnimation(parent: _shake, curve: Curves.easeOut));

  late final Animation<double> _pop = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.18), weight: 28),
    TweenSequenceItem(tween: Tween(begin: 1.18, end: 0.96), weight: 22),
    TweenSequenceItem(tween: Tween(begin: 0.96, end: 1.08), weight: 50),
  ]).animate(CurvedAnimation(parent: _shake, curve: Curves.easeOutCubic));

  late final Animation<double> _lift = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: -2.4), weight: 30),
    TweenSequenceItem(tween: Tween(begin: -2.4, end: 0.6), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 0.6, end: 0.0), weight: 40),
  ]).animate(CurvedAnimation(parent: _shake, curve: Curves.easeOut));

  @override
  void didUpdateWidget(covariant _DockTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) {
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final idle = widget.immersive
        ? Colors.white.withValues(alpha: 0.58)
        : const Color(0xFF6A7380);
    final active = widget.immersive ? const Color(0xFFFF8A6B) : kPlayerPrimary;
    final color = widget.selected ? active : idle;

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          splashColor: active.withValues(alpha: 0.12),
          highlightColor: Colors.transparent,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _shake,
                builder: (context, child) {
                  final playing = _shake.isAnimating;
                  final scale = playing
                      ? _pop.value
                      : (widget.selected ? 1.08 : 1.0);
                  final dy = playing ? _lift.value : 0.0;
                  final rot = playing ? _angle.value : 0.0;
                  return Transform.translate(
                    offset: Offset(0, dy),
                    child: Transform.rotate(
                      angle: rot,
                      child: Transform.scale(
                        scale: scale,
                        child: child,
                      ),
                    ),
                  );
                },
                child: _DockGlyph(
                  kind: widget.kind,
                  filled: widget.selected,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: widget.selected ? FontWeight.w800 : FontWeight.w600,
                  height: 1.0,
                  letterSpacing: 0.2,
                ),
                child: Text(widget.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _DockGlyphKind { home, theater, message, profile }

/// 统一笔触的自绘图标：短剧语义，非整套 Material 默认
class _DockGlyph extends StatelessWidget {
  final _DockGlyphKind kind;
  final bool filled;
  final Color color;
  final double size;

  const _DockGlyph({
    required this.kind,
    required this.filled,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _DockGlyphPainter(kind: kind, filled: filled, color: color),
    );
  }
}

class _DockGlyphPainter extends CustomPainter {
  final _DockGlyphKind kind;
  final bool filled;
  final Color color;

  _DockGlyphPainter({
    required this.kind,
    required this.filled,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = filled ? 1.7 : 1.55
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (kind) {
      case _DockGlyphKind.home:
        _paintHome(canvas, size, stroke, fill);
      case _DockGlyphKind.theater:
        _paintTheater(canvas, size, stroke, fill);
      case _DockGlyphKind.message:
        _paintMessage(canvas, size, stroke, fill);
      case _DockGlyphKind.profile:
        _paintProfile(canvas, size, stroke, fill);
    }
  }

  /// 竖屏胶片 + 播放三角 —— 短剧首页语义
  void _paintHome(Canvas canvas, Size size, Paint stroke, Paint fill) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.18, size.height * 0.08, size.width * 0.64, size.height * 0.84),
      const Radius.circular(3.2),
    );
    if (filled) {
      canvas.drawRRect(r, fill);
      final cut = Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..style = PaintingStyle.fill;
      // 胶片齿孔
      for (final y in [0.22, 0.50, 0.78]) {
        canvas.drawCircle(Offset(size.width * 0.28, size.height * y), 1.05, cut);
        canvas.drawCircle(Offset(size.width * 0.72, size.height * y), 1.05, cut);
      }
      // 白三角
      final tri = Path()
        ..moveTo(size.width * 0.40, size.height * 0.32)
        ..lineTo(size.width * 0.40, size.height * 0.68)
        ..lineTo(size.width * 0.68, size.height * 0.50)
        ..close();
      canvas.drawPath(tri, Paint()..color = Colors.white.withValues(alpha: 0.95));
    } else {
      canvas.drawRRect(r, stroke);
      for (final y in [0.26, 0.50, 0.74]) {
        canvas.drawCircle(Offset(size.width * 0.30, size.height * y), 0.9, stroke);
        canvas.drawCircle(Offset(size.width * 0.70, size.height * y), 0.9, stroke);
      }
      final tri = Path()
        ..moveTo(size.width * 0.42, size.height * 0.34)
        ..lineTo(size.width * 0.42, size.height * 0.66)
        ..lineTo(size.width * 0.66, size.height * 0.50)
        ..close();
      canvas.drawPath(tri, stroke);
    }
  }

  /// 双幕帘 / 舞台框 —— 剧场
  void _paintTheater(Canvas canvas, Size size, Paint stroke, Paint fill) {
    final frame = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.10, size.height * 0.18, size.width * 0.80, size.height * 0.64),
      const Radius.circular(2.8),
    );
    // 左幕
    final left = Path()
      ..moveTo(size.width * 0.12, size.height * 0.20)
      ..quadraticBezierTo(size.width * 0.28, size.height * 0.38, size.width * 0.18, size.height * 0.80)
      ..lineTo(size.width * 0.12, size.height * 0.80)
      ..close();
    // 右幕
    final right = Path()
      ..moveTo(size.width * 0.88, size.height * 0.20)
      ..quadraticBezierTo(size.width * 0.72, size.height * 0.38, size.width * 0.82, size.height * 0.80)
      ..lineTo(size.width * 0.88, size.height * 0.80)
      ..close();
    // 顶帷
    final valance = Path()
      ..moveTo(size.width * 0.12, size.height * 0.22)
      ..quadraticBezierTo(size.width * 0.35, size.height * 0.38, size.width * 0.50, size.height * 0.26)
      ..quadraticBezierTo(size.width * 0.65, size.height * 0.38, size.width * 0.88, size.height * 0.22);

    if (filled) {
      canvas.drawRRect(frame, fill);
      final cut = Paint()..color = Colors.white.withValues(alpha: 0.22);
      canvas.drawPath(left, cut);
      canvas.drawPath(right, cut);
      canvas.drawPath(
        valance,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round,
      );
      // 舞台星点
      canvas.drawCircle(Offset(size.width * 0.50, size.height * 0.52), 1.4, Paint()..color = Colors.white);
    } else {
      canvas.drawRRect(frame, stroke);
      canvas.drawPath(left, stroke);
      canvas.drawPath(right, stroke);
      canvas.drawPath(valance, stroke);
      canvas.drawCircle(Offset(size.width * 0.50, size.height * 0.54), 1.1, stroke);
    }
  }

  /// 对话气泡 —— 消息
  void _paintMessage(Canvas canvas, Size size, Paint stroke, Paint fill) {
    final bubble = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.14, size.height * 0.12, size.width * 0.72, size.height * 0.58),
      const Radius.circular(5.5),
    );
    final tail = Path()
      ..moveTo(size.width * 0.28, size.height * 0.68)
      ..lineTo(size.width * 0.22, size.height * 0.88)
      ..lineTo(size.width * 0.44, size.height * 0.70)
      ..close();

    if (filled) {
      canvas.drawRRect(bubble, fill);
      canvas.drawPath(tail, fill);
      final line = Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..strokeWidth = 1.35
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(size.width * 0.28, size.height * 0.32),
        Offset(size.width * 0.70, size.height * 0.32),
        line,
      );
      canvas.drawLine(
        Offset(size.width * 0.28, size.height * 0.46),
        Offset(size.width * 0.58, size.height * 0.46),
        line,
      );
    } else {
      canvas.drawRRect(bubble, stroke);
      canvas.drawPath(tail, stroke);
      canvas.drawLine(
        Offset(size.width * 0.28, size.height * 0.32),
        Offset(size.width * 0.70, size.height * 0.32),
        stroke,
      );
      canvas.drawLine(
        Offset(size.width * 0.28, size.height * 0.46),
        Offset(size.width * 0.58, size.height * 0.46),
        stroke,
      );
    }
  }

  /// 柔和头肩轮廓 —— 我的
  void _paintProfile(Canvas canvas, Size size, Paint stroke, Paint fill) {
    final head = Offset(size.width * 0.50, size.height * 0.32);
    final headR = size.width * 0.20;
    final shoulder = Path()
      ..moveTo(size.width * 0.14, size.height * 0.92)
      ..quadraticBezierTo(size.width * 0.18, size.height * 0.58, size.width * 0.50, size.height * 0.58)
      ..quadraticBezierTo(size.width * 0.82, size.height * 0.58, size.width * 0.86, size.height * 0.92);

    if (filled) {
      canvas.drawCircle(head, headR, fill);
      canvas.drawPath(shoulder, fill);
    } else {
      canvas.drawCircle(head, headR, stroke);
      canvas.drawPath(shoulder, stroke);
      // 肩线闭合感：底部不封死，更轻
      final tip = math.pi / 2;
      canvas.drawArc(
        Rect.fromCircle(center: head, radius: headR),
        tip,
        0.001,
        false,
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DockGlyphPainter oldDelegate) {
    return oldDelegate.kind != kind ||
        oldDelegate.filled != filled ||
        oldDelegate.color != color;
  }
}
