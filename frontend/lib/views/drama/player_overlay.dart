import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

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

class PlayerCoinChip extends StatelessWidget {
  final int balance;
  final VoidCallback? onTap;
  const PlayerCoinChip({super.key, required this.balance, this.onTap});

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.monetization_on_rounded, size: 14, color: Colors.amber.shade300),
          const SizedBox(width: 4),
          Text(
            '$balance',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5),
          ),
        ],
      ),
    );
    if (onTap == null) return chip;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: chip);
  }
}

/// 红果风顶部「更多」收纳：真毛玻璃 + 柔和背影
class PlayerMoreButton extends StatelessWidget {
  final VoidCallback onTap;
  const PlayerMoreButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '更多',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 背影光晕
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 14,
                      spreadRadius: 0.5,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, -1),
                    ),
                  ],
                ),
              ),
              ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.28),
                          Colors.white.withValues(alpha: 0.08),
                          Colors.black.withValues(alpha: 0.28),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                        width: 0.9,
                      ),
                    ),
                    child: Center(
                      child: CustomPaint(
                        size: const Size(15, 15),
                        painter: _MoreDotsPainter(
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreDotsPainter extends CustomPainter {
  final Color color;
  _MoreDotsPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color;
    final glow = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
    final r = size.shortestSide * 0.125;
    final gap = size.shortestSide * 0.26;
    final cx = size.width / 2;
    final cy = size.height / 2;
    for (final dx in [-gap, gap]) {
      for (final dy in [-gap, gap]) {
        final o = Offset(cx + dx, cy + dy);
        canvas.drawCircle(o, r + 0.6, glow);
        canvas.drawCircle(o, r, fill);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MoreDotsPainter oldDelegate) => oldDelegate.color != color;
}

/// 顶部集数胶囊：第 N / 总集
class PlayerEpisodeIndexChip extends StatelessWidget {
  final int current;
  final int total;
  final VoidCallback? onTap;

  const PlayerEpisodeIndexChip({
    super.key,
    required this.current,
    required this.total,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.movie_filter_rounded, size: 13, color: Colors.white.withValues(alpha: 0.88)),
          const SizedBox(width: 5),
          Text(
            '$current / $total',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.3,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return chip;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: chip);
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

class PlayerBottomMeta extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onTitleTap;
  final VoidCallback? onEpisodeTap;
  final ValueChanged<String>? onTagTap;

  const PlayerBottomMeta({
    super.key,
    required this.title,
    required this.subtitle,
    this.onTitleTap,
    this.onEpisodeTap,
    this.onTagTap,
  });

  static const _titleShadow = <Shadow>[
    Shadow(color: Color(0xCC000000), blurRadius: 12, offset: Offset(0, 2)),
    Shadow(color: Color(0x66000000), blurRadius: 3, offset: Offset(0, 1)),
  ];

  @override
  Widget build(BuildContext context) {
    final parts = subtitle
        .split('·')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final ep = parts.isNotEmpty ? parts.first : '';
    final tags = parts.length > 1 ? parts.sublist(1) : const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTitleTap,
          behavior: HitTestBehavior.opaque,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 3,
                height: 16,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFF8A6B), kPlayerPrimary],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: kPlayerPrimary.withValues(alpha: 0.45),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFFAFAFA),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                          letterSpacing: 0.8,
                          fontFamily: 'PingFang SC',
                          fontFamilyFallback: ['SF Pro Display', 'Microsoft YaHei', 'sans-serif'],
                          shadows: _titleShadow,
                        ),
                      ),
                    ),
                    if (onTitleTap != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 1),
                        child: Transform.translate(
                          // chevron_right 字形略偏上，光学贴齐标题中线
                          offset: const Offset(-1, 0.5),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (ep.isNotEmpty || tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              if (ep.isNotEmpty)
                GestureDetector(
                  onTap: onEpisodeTap,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(8, 3, onEpisodeTap != null ? 4 : 8, 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      color: Colors.white.withValues(alpha: 0.12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ep,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                            letterSpacing: 0.3,
                            fontFamily: 'PingFang SC',
                            fontFamilyFallback: const ['SF Pro Text', 'Microsoft YaHei', 'sans-serif'],
                          ),
                        ),
                        if (onEpisodeTap != null)
                          Icon(
                            Icons.expand_more_rounded,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                      ],
                    ),
                  ),
                ),
              for (final tag in tags) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '·',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Flexible(
                  child: GestureDetector(
                    onTap: onTagTap == null ? null : () => onTagTap!(tag),
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      tag,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: onTagTap != null ? 0.88 : 0.72),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                        letterSpacing: 0.4,
                        decoration: onTagTap != null ? TextDecoration.underline : null,
                        decorationColor: Colors.white.withValues(alpha: 0.28),
                        fontFamily: 'PingFang SC',
                        fontFamilyFallback: const ['SF Pro Text', 'Microsoft YaHei', 'sans-serif'],
                        shadows: const [
                          Shadow(color: Color(0x88000000), blurRadius: 6, offset: Offset(0, 1)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class PlayerSideAction extends StatelessWidget {
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

  /// Material 书签字形视觉重心偏左，圆内光学居中需微右移
  Offset get _opticalNudge {
    if (icon == Icons.bookmark_rounded || icon == Icons.bookmark_border_rounded) {
      return const Offset(1.2, 0);
    }
    if (icon == Icons.list_alt_rounded) {
      return const Offset(0.4, 0);
    }
    return Offset.zero;
  }

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? Colors.white;
    final nudge = _opticalNudge;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Transform.translate(
                offset: nudge,
                child: Icon(icon, color: color, size: 26),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                shadows: const [Shadow(color: Color(0x99000000), blurRadius: 4)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 红果风进度条：细轨 + 微光填充，拖拽时加粗并显示时间
class PlayerProgressBar extends StatefulWidget {
  final VideoPlayerController? controller;
  final ValueChanged<Duration>? onSeek;

  const PlayerProgressBar({super.key, required this.controller, this.onSeek});

  @override
  State<PlayerProgressBar> createState() => _PlayerProgressBarState();
}

class _PlayerProgressBarState extends State<PlayerProgressBar> {
  bool _dragging = false;
  double _dragValue = 0;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onTick);
  }

  @override
  void didUpdateWidget(covariant PlayerProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onTick);
      widget.controller?.addListener(_onTick);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    if (!_dragging && mounted) setState(() {});
  }

  void _seekTo(double ratio, double width) {
    final c = widget.controller;
    if (c == null || !c.value.isInitialized || width <= 0) return;
    final dur = c.value.duration;
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
    final c = widget.controller;
    if (c == null || !c.value.isInitialized) {
      return const SizedBox(height: 20);
    }
    final total = c.value.duration;
    final durMs = total.inMilliseconds;
    final posMs = c.value.position.inMilliseconds;
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
