import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

const kPlayerPrimary = Color(0xFFFF6B4A); // 红果偏暖橙红点缀
const kPlayerAccent = Color(0xFF2ED3BE);

/// 首页底栏内容高度（不含系统手势区）
const kHomeBottomBarHeight = 56.0;

/// 播放器底部避让：系统手势区 + 可选首页浮底栏
double playerBottomInset(BuildContext context, {required bool withHomeBar}) {
  final safe = MediaQuery.viewPaddingOf(context).bottom;
  return safe + (withHomeBar ? kHomeBottomBarHeight : 0);
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
  const PlayerCoinChip({super.key, required this.balance});

  @override
  Widget build(BuildContext context) {
    return Container(
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

  const PlayerBottomMeta({
    super.key,
    required this.title,
    required this.subtitle,
    this.onTitleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTitleTap,
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              shadows: [Shadow(color: Color(0x88000000), blurRadius: 8)],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: 13,
            fontWeight: FontWeight.w500,
            shadows: const [Shadow(color: Color(0x88000000), blurRadius: 6)],
          ),
        ),
      ],
    );
  }
}

class PlayerSideAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final bool active;

  const PlayerSideAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? Colors.white;
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
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Icon(icon, color: color, size: 26),
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

/// 细进度条：拖拽 seek（红果底部进度感）
class PlayerProgressBar extends StatefulWidget {
  final VideoPlayerController? controller;
  const PlayerProgressBar({super.key, required this.controller});

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

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    if (c == null || !c.value.isInitialized) {
      return const SizedBox(height: 18);
    }
    final dur = c.value.duration.inMilliseconds;
    final pos = c.value.position.inMilliseconds;
    final value = _dragging
        ? _dragValue
        : (dur <= 0 ? 0.0 : (pos / dur).clamp(0.0, 1.0));

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: _dragging ? 3.5 : 2,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: _dragging ? 6 : 0.1),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        activeTrackColor: Colors.white.withValues(alpha: 0.92),
        inactiveTrackColor: Colors.white.withValues(alpha: 0.22),
        thumbColor: Colors.white,
        overlayColor: Colors.white.withValues(alpha: 0.12),
      ),
      child: Slider(
        value: value,
        onChangeStart: (v) {
          setState(() {
            _dragging = true;
            _dragValue = v;
          });
        },
        onChanged: (v) => setState(() => _dragValue = v),
        onChangeEnd: (v) async {
          final ms = (dur * v).round();
          await c.seekTo(Duration(milliseconds: ms));
          if (mounted) {
            setState(() {
              _dragging = false;
              _dragValue = v;
            });
          }
        },
      ),
    );
  }
}
