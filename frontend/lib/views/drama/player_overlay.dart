import 'package:flutter/material.dart';
import 'player_handle.dart';

export '../../widgets/player/player_bottom_meta.dart';

const kPlayerPrimary = Color(0xFFFF6B4A); // 红果偏暖橙红点缀
const kPlayerAccent = Color(0xFF2ED3BE);

/// 贴底胶囊视觉占用（高度 + 贴底间隙），用于非首页内容垫高
const kHomeBottomBarHeight = 60.0;

/// 播放器底部避让：贴底胶囊不再叠算整段 safe，避免标题悬空
double playerBottomInset(BuildContext context, {required bool withHomeBar}) {
  final safe = MediaQuery.viewPaddingOf(context).bottom;
  if (!withHomeBar) return safe;
  final dockLift = safe > 0 ? 2.0 + safe * 0.15 : 6.0;
  return dockLift + kHomeBottomBarHeight + 4;
}

/// 缓冲中轻提示（不挡手势）
class PlayerBufferingHint extends StatefulWidget {
  final PlayHandle? handle;
  final bool enabled;

  const PlayerBufferingHint({super.key, required this.handle, this.enabled = true});

  @override
  State<PlayerBufferingHint> createState() => _PlayerBufferingHintState();
}

class _PlayerBufferingHintState extends State<PlayerBufferingHint> {
  @override
  void initState() {
    super.initState();
    widget.handle?.addListener(_onTick);
  }

  @override
  void didUpdateWidget(covariant PlayerBufferingHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.handle != widget.handle) {
      oldWidget.handle?.removeListener(_onTick);
      widget.handle?.addListener(_onTick);
    }
  }

  @override
  void dispose() {
    widget.handle?.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.handle;
    if (!widget.enabled || h == null || !h.isInitialized || !h.isBuffering) {
      return const SizedBox.shrink();
    }
    return const IgnorePointer(
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white70),
        ),
      ),
    );
  }
}

/// 底部可读性渐变（红果沉浸播放）
class PlayerBottomScrim extends StatelessWidget {
  const PlayerBottomScrim({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Color(0x33000000),
              Color(0x99000000),
              Color(0xE6000000),
            ],
            stops: [0.0, 0.35, 0.7, 1.0],
          ),
        ),
      ),
    );
  }
}

class PlayerTopScrim extends StatelessWidget {
  const PlayerTopScrim({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x99000000), Colors.transparent],
          ),
        ),
      ),
    );
  }
}

/// 长按倍速提示条
class PlayerSpeedBadge extends StatelessWidget {
  final String label;
  const PlayerSpeedBadge({super.key, this.label = '2.0x 快进中'});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0x99000000),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fast_forward_rounded, size: 16, color: kPlayerPrimary.withValues(alpha: 0.95)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 播放失败重试面板
class PlayerPlaybackErrorPanel extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const PlayerPlaybackErrorPanel({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('播放失败', style: TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}

/// 锁定蒙层 + 解锁按钮
class PlayerUnlockGate extends StatelessWidget {
  final VoidCallback onUnlock;

  const PlayerUnlockGate({super.key, required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: FilledButton(onPressed: onUnlock, child: const Text('解锁本集')),
      ),
    );
  }
}

/// 全屏点击 / 双击 / 长按手势层
class PlayerGestureSurface extends StatelessWidget {
  final VoidCallback onTap;
  final GestureTapDownCallback onDoubleTapDown;
  final GestureLongPressStartCallback onLongPressStart;
  final GestureLongPressEndCallback onLongPressEnd;
  final VoidCallback onLongPressCancel;

  const PlayerGestureSurface({
    super.key,
    required this.onTap,
    required this.onDoubleTapDown,
    required this.onLongPressStart,
    required this.onLongPressEnd,
    required this.onLongPressCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onDoubleTapDown: onDoubleTapDown,
        onLongPressStart: onLongPressStart,
        onLongPressEnd: onLongPressEnd,
        onLongPressCancel: onLongPressCancel,
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// 加载 / 缓冲 / 错误 / 锁定 / 暂停提示 / 倍速 / 点赞爆发
class PlayerPlaybackStatusStack extends StatelessWidget {
  final bool loading;
  final bool locked;
  final bool speedUp;
  final bool showPauseHint;
  final bool paused;
  final PlayHandle? player;
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onUnlock;
  final Offset? burstPos;
  final bool showBuffering;

  const PlayerPlaybackStatusStack({
    super.key,
    required this.loading,
    required this.locked,
    required this.speedUp,
    required this.showPauseHint,
    required this.paused,
    required this.player,
    required this.error,
    required this.onRetry,
    required this.onUnlock,
    this.burstPos,
    this.showBuffering = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (burstPos != null) PlayerLikeBurst(localPos: burstPos!),
        if (loading) const Center(child: CircularProgressIndicator(color: Colors.white)),
        if (!loading && !locked && showBuffering) PlayerBufferingHint(handle: player),
        if (error != null) PlayerPlaybackErrorPanel(message: error!, onRetry: onRetry),
        if (locked) PlayerUnlockGate(onUnlock: onUnlock),
        if (showPauseHint && !locked && !loading && !speedUp) PlayerPauseHint(paused: paused),
        if (speedUp)
          const Positioned(
            top: 120,
            left: 0,
            right: 0,
            child: PlayerSpeedBadge(),
          ),
      ],
    );
  }
}

/// 片尾下一集提示
class PlayerNextEpisodeHint extends StatelessWidget {
  final String episodeLabel;
  final VoidCallback onTap;

  const PlayerNextEpisodeHint({
    super.key,
    required this.episodeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            color: Colors.black.withValues(alpha: 0.48),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.skip_next_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 4),
              Text(
                '下一集 · $episodeLabel',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlayerPauseHint extends StatelessWidget {
  final bool paused;
  const PlayerPauseHint({super.key, required this.paused});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: AnimatedOpacity(
          opacity: 1,
          duration: const Duration(milliseconds: 120),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.42),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Icon(
              paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              color: Colors.white,
              size: 44,
            ),
          ),
        ),
      ),
    );
  }
}

/// 播放侧栏统一组件（首页 / 剧集页共用同一套槽位与图标规格）
class PlayerSideAction extends StatelessWidget {
  static const double slotWidth = 52;
  static const double _circleSize = 44;
  static const double _iconSize = 24;
  static const double _labelHeight = 16;
  static const double _gap = 4;
  static const double _vPad = 6;

  static const double itemExtent = _vPad * 2 + _circleSize + _gap + _labelHeight;

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  const PlayerSideAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? Colors.white;
    return SizedBox(
      width: slotWidth,
      height: itemExtent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          children: [
            const SizedBox(height: _vPad),
            SizedBox(
              width: slotWidth,
              height: _circleSize,
              child: Center(
                child: Container(
                  width: _circleSize,
                  height: _circleSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.22),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Icon(icon, color: color, size: _iconSize),
                ),
              ),
            ),
            const SizedBox(height: _gap),
            SizedBox(
              width: slotWidth,
              height: _labelHeight,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.0,
                  leadingDistribution: TextLeadingDistribution.even,
                  shadows: const [Shadow(color: Color(0x99000000), blurRadius: 4)],
                ),
              ),
            ),
            const SizedBox(height: _vPad),
          ],
        ),
      ),
    );
  }
}

/// 红果风进度条：细轨 + 微光填充，拖拽时加粗并显示时间
class PlayerProgressBar extends StatefulWidget {
  final PlayHandle? handle;
  final ValueChanged<Duration>? onSeek;

  const PlayerProgressBar({super.key, required this.handle, this.onSeek});

  @override
  State<PlayerProgressBar> createState() => _PlayerProgressBarState();
}

class _PlayerProgressBarState extends State<PlayerProgressBar> {
  bool _dragging = false;
  double _dragValue = 0;

  @override
  void initState() {
    super.initState();
    widget.handle?.addListener(_onTick);
  }

  @override
  void didUpdateWidget(covariant PlayerProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.handle != widget.handle) {
      oldWidget.handle?.removeListener(_onTick);
      widget.handle?.addListener(_onTick);
    }
  }

  @override
  void dispose() {
    widget.handle?.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    if (!_dragging && mounted) setState(() {});
  }

  void _seekTo(double ratio, double width) {
    final c = widget.handle;
    if (c == null || !c.isInitialized || width <= 0) return;
    final dur = c.duration;
    if (dur.inMilliseconds <= 0) return;
    final target = Duration(milliseconds: (dur.inMilliseconds * ratio.clamp(0.0, 1.0)).round());
    c.seekTo(target);
    widget.onSeek?.call(target);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.handle;
    if (c == null || !c.isInitialized) {
      return const SizedBox(height: 20);
    }
    final total = c.duration;
    final durMs = total.inMilliseconds;
    final posMs = c.position.inMilliseconds;
    final value = _dragging ? _dragValue : (durMs <= 0 ? 0.0 : (posMs / durMs).clamp(0.0, 1.0));
    final trackH = _dragging ? 4.0 : 2.2;
    final thumb = _dragging ? 12.0 : 5.0;
    final shown = Duration(milliseconds: (durMs * value).round());

    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_dragging)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${_fmt(shown)}  /  ${_fmt(total)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  shadows: const [Shadow(color: Color(0x99000000), blurRadius: 8)],
                ),
              ),
            ),
          SizedBox(
            height: 24,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (d) {
                    setState(() {
                      _dragging = true;
                      _dragValue = (d.localPosition.dx / w).clamp(0.0, 1.0);
                    });
                  },
                  onHorizontalDragUpdate: (d) {
                    setState(() => _dragValue = (d.localPosition.dx / w).clamp(0.0, 1.0));
                  },
                  onHorizontalDragEnd: (_) {
                    _seekTo(_dragValue, w);
                    setState(() => _dragging = false);
                  },
                  onTapDown: (d) {
                    final v = (d.localPosition.dx / w).clamp(0.0, 1.0);
                    setState(() {
                      _dragging = true;
                      _dragValue = v;
                    });
                    _seekTo(v, w);
                    Future<void>.delayed(const Duration(milliseconds: 160), () {
                      if (mounted) setState(() => _dragging = false);
                    });
                  },
                  child: Center(
                    child: SizedBox(
                      height: trackH + thumb,
                      width: w,
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        clipBehavior: Clip.none,
                        children: [
                          // 底轨
                          Container(
                            height: trackH,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(99),
                              color: Colors.white.withValues(alpha: 0.16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.06),
                                width: 0.5,
                              ),
                            ),
                          ),
                          // 已播：暖白微光
                          FractionallySizedBox(
                            widthFactor: value.clamp(0.0, 1.0),
                            child: Container(
                              height: trackH,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(99),
                                gradient: LinearGradient(
                                  colors: _dragging
                                      ? const [Color(0xFFFFB39A), Color(0xFFFF6B4A)]
                                      : [
                                          Colors.white.withValues(alpha: 0.95),
                                          const Color(0xFFFFE4DC),
                                        ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_dragging ? kPlayerPrimary : Colors.white)
                                        .withValues(alpha: _dragging ? 0.45 : 0.28),
                                    blurRadius: _dragging ? 10 : 6,
                                    spreadRadius: _dragging ? 0.5 : 0,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // 拇指
                          Positioned(
                            left: (w * value - thumb / 2).clamp(0.0, (w - thumb).clamp(0.0, w)),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              curve: Curves.easeOutCubic,
                              width: thumb,
                              height: thumb,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(
                                  color: _dragging
                                      ? kPlayerPrimary.withValues(alpha: 0.85)
                                      : Colors.white.withValues(alpha: 0.35),
                                  width: _dragging ? 1.5 : 0.8,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    blurRadius: 6,
                                    offset: const Offset(0, 1),
                                  ),
                                  if (_dragging)
                                    BoxShadow(
                                      color: kPlayerPrimary.withValues(alpha: 0.4),
                                      blurRadius: 10,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 双击点赞飘心
class PlayerLikeBurst extends StatelessWidget {
  final Offset localPos;
  const PlayerLikeBurst({super.key, required this.localPos});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: localPos.dx - 36,
      top: localPos.dy - 36,
      child: const IgnorePointer(
        child: _BurstHeart(),
      ),
    );
  }
}

class _BurstHeart extends StatefulWidget {
  const _BurstHeart();

  @override
  State<_BurstHeart> createState() => _BurstHeartState();
}

class _BurstHeartState extends State<_BurstHeart> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _c, curve: const Interval(0.45, 1))),
      child: ScaleTransition(
        scale: Tween(begin: 0.6, end: 1.35).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack)),
        child: const Icon(Icons.favorite_rounded, color: kPlayerPrimary, size: 72),
      ),
    );
  }
}
