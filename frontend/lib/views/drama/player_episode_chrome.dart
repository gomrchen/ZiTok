import 'package:flutter/material.dart';

String formatPlayerCount(int n) {
  if (n <= 0) return '';
  if (n >= 10000) {
    final v = n / 10000;
    final s = v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    return '$s万';
  }
  if (n >= 1000) {
    final v = n / 1000;
    return '${v.toStringAsFixed(1)}千';
  }
  return '$n';
}

/// 顶栏纯文字集数：第 N 集
class PlayerEpisodeTitleLabel extends StatelessWidget {
  final int episodeNo;
  final VoidCallback? onTap;

  const PlayerEpisodeTitleLabel({
    super.key,
    required this.episodeNo,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Text(
        '第$episodeNo集',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          shadows: [Shadow(color: Color(0x99000000), blurRadius: 8, offset: Offset(0, 1))],
        ),
      ),
    );
  }
}

/// 顶栏「倍速」文字按钮
class PlayerSpeedTextButton extends StatelessWidget {
  final double speed;
  final VoidCallback onTap;

  const PlayerSpeedTextButton({
    super.key,
    required this.speed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = speed == 1.0 ? '倍速' : '${speed}x';
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            shadows: [Shadow(color: Color(0x99000000), blurRadius: 6)],
          ),
        ),
      ),
    );
  }
}

/// 底栏：选集胶囊 + 小窗/沉浸
class PlayerEpisodeDock extends StatelessWidget {
  final int totalEpisodes;
  final bool freeWatch;
  final VoidCallback onPickEpisodes;
  final VoidCallback onToggleChrome;
  final bool chromeHidden;

  const PlayerEpisodeDock({
    super.key,
    required this.totalEpisodes,
    required this.onPickEpisodes,
    required this.onToggleChrome,
    this.freeWatch = true,
    this.chromeHidden = false,
  });

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context).bottom;
    return Container(
      color: Colors.black,
      padding: EdgeInsets.fromLTRB(14, 8, 10, 8 + safe),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: onPickEpisodes,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          freeWatch
                              ? '选集·全$totalEpisodes集·免费观看'
                              : '选集·全$totalEpisodes集',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.15,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_up_rounded,
                        color: Colors.white.withValues(alpha: 0.75),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: onToggleChrome,
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 44,
                height: 42,
                child: Icon(
                  chromeHidden
                      ? Icons.fullscreen_exit_rounded
                      : Icons.picture_in_picture_alt_outlined,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 供侧栏底部对齐用：Dock 视觉高度（不含 safe）
double playerEpisodeDockHeight(BuildContext context) {
  return 58 + MediaQuery.paddingOf(context).bottom;
}
