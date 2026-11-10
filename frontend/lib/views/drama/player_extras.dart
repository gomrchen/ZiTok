import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:video_player/video_player.dart';

import '../../models/drama_models.dart';
import 'player_overlay.dart';

/// 复制分享文案（无需额外 share 插件，联调稳定）
Future<void> shareDramaEpisode(BuildContext context, {required Drama drama, required Episode episode}) async {
  final text =
      '《${drama.title}》第${episode.episodeNo}集 · ${drama.category.isEmpty ? '短剧' : drama.category}\n来 ZiTok 一起追：zitok://drama/${drama.id}?ep=${episode.id}';
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('分享文案已复制'),
      behavior: SnackBarBehavior.floating,
      duration: Duration(milliseconds: 1400),
    ),
  );
}

Future<double?> showPlayerSpeedSheet(BuildContext context, {required double current}) {
  const speeds = <({double value, String label})>[
    (value: 0.75, label: '0.75x'),
    (value: 1.0, label: '1.0x'),
    (value: 1.25, label: '1.25x'),
    (value: 1.5, label: '1.5x'),
    (value: 2.0, label: '2.0x'),
  ];
  return showModalBottomSheet<double>(
    context: context,
    backgroundColor: const Color(0xFF16181F),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '播放倍速',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                '长按画面可临时 2.0x，松手恢复',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (var i = 0; i < speeds.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _SpeedOption(
                        label: speeds[i].label,
                        selected: (current - speeds[i].value).abs() < 0.01,
                        onTap: () => Navigator.pop(ctx, speeds[i].value),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _SpeedOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SpeedOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFF7A5C), kPlayerPrimary],
                  )
                : null,
            color: selected ? null : Colors.white.withValues(alpha: 0.08),
            border: Border.all(
              color: selected
                  ? kPlayerPrimary.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white.withValues(alpha: 0.82),
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showPlayerDramaIntroSheet(BuildContext context, {required Drama drama}) {
  final tags = drama.tags
      .split(RegExp(r'[,，、\s]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF16181F),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 72,
                      height: 96,
                      child: drama.coverUrl.isEmpty
                          ? const ColoredBox(color: Color(0xFF2A2D36))
                          : Image.network(drama.coverUrl, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          drama.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${drama.totalEpisodes}集 · 免费${drama.freeEpisodeCount}集'
                          '${drama.bundlePrice > 0 ? ' · 整剧${drama.bundlePrice}币' : ''}',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12.5),
                        ),
                        if (drama.category.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            drama.category,
                            style: TextStyle(color: kPlayerPrimary.withValues(alpha: 0.95), fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in tags.take(8))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          color: Colors.white.withValues(alpha: 0.08),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Text(t, style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Text(
                '剧情简介',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                drama.description.trim().isEmpty ? '暂无简介' : drama.description.trim(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

enum PlayerMoreAction { speed, mute, intro, share }

/// 红果式「更多」收纳：倍速 / 静音 / 简介 / 分享
Future<PlayerMoreAction?> showPlayerMoreSheet(
  BuildContext context, {
  required bool muted,
  required double speed,
}) {
  final speedLabel = speed == speed.roundToDouble() ? '${speed.toStringAsFixed(0)}x' : '${speed}x';
  return showModalBottomSheet<PlayerMoreAction>(
    context: context,
    backgroundColor: const Color(0xFF16181F),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: Icon(Icons.apps_rounded, size: 15, color: Colors.white.withValues(alpha: 0.85)),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    '更多功能',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _MoreTile(
                      icon: Icons.speed_rounded,
                      label: '倍速',
                      hint: speedLabel,
                      accent: speed != 1.0,
                      onTap: () => Navigator.pop(ctx, PlayerMoreAction.speed),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MoreTile(
                      icon: muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      label: muted ? '开声' : '静音',
                      hint: muted ? '已静音' : '有声',
                      onTap: () => Navigator.pop(ctx, PlayerMoreAction.mute),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MoreTile(
                      icon: Icons.info_outline_rounded,
                      label: '简介',
                      hint: '剧情介绍',
                      onTap: () => Navigator.pop(ctx, PlayerMoreAction.intro),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MoreTile(
                      icon: Icons.ios_share_rounded,
                      label: '分享',
                      hint: '复制链接',
                      onTap: () => Navigator.pop(ctx, PlayerMoreAction.share),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '手势 · 左侧调亮度 · 右侧调音量 · 长按 2 倍速',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.42),
                  fontSize: 11.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _MoreTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;
  final bool accent;

  const _MoreTile({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: accent ? kPlayerPrimary.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (accent ? kPlayerPrimary : Colors.white).withValues(alpha: 0.12),
                ),
                child: Icon(icon, size: 18, color: accent ? kPlayerPrimary : Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hint,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 左右缘竖滑：左亮度 / 右音量
class PlayerEdgeGestureLayer extends StatefulWidget {
  final VideoPlayerController? controller;
  final bool enabled;

  const PlayerEdgeGestureLayer({
    super.key,
    required this.controller,
    this.enabled = true,
  });

  @override
  State<PlayerEdgeGestureLayer> createState() => _PlayerEdgeGestureLayerState();
}

class _PlayerEdgeGestureLayerState extends State<PlayerEdgeGestureLayer> {
  bool _show = false;
  bool _isBrightness = true;
  double _value = 0.5;
  Timer? _hide;

  Future<void> _ensureBrightness() async {
    try {
      _value = await ScreenBrightness().application;
    } catch (_) {
      _value = 0.5;
    }
  }

  void _pulse() {
    _hide?.cancel();
    setState(() => _show = true);
    _hide = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _show = false);
    });
  }

  Future<void> _onBright(DragUpdateDetails d, double h) async {
    final delta = -d.delta.dy / h;
    try {
      final cur = await ScreenBrightness().application;
      final next = (cur + delta).clamp(0.0, 1.0);
      await ScreenBrightness().setApplicationScreenBrightness(next);
      if (!mounted) return;
      setState(() {
        _isBrightness = true;
        _value = next;
      });
      _pulse();
    } catch (_) {}
  }

  Future<void> _onVolume(DragUpdateDetails d, double h) async {
    final c = widget.controller;
    if (c == null || !c.value.isInitialized) return;
    final delta = -d.delta.dy / h;
    final next = (c.value.volume + delta).clamp(0.0, 1.0);
    await c.setVolume(next);
    if (!mounted) return;
    setState(() {
      _isBrightness = false;
      _value = next;
    });
    _pulse();
  }

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 0,
          top: 100,
          bottom: 140,
          width: 40,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragStart: (_) => _ensureBrightness(),
            onVerticalDragUpdate: (d) {
              final h = context.size?.height ?? 600;
              _onBright(d, h);
            },
          ),
        ),
        Positioned(
          right: 0,
          top: 100,
          bottom: 140,
          width: 40,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragUpdate: (d) {
              final h = context.size?.height ?? 600;
              _onVolume(d, h);
            },
          ),
        ),
        if (_show)
          IgnorePointer(
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xB3000000),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isBrightness
                            ? (_value < 0.2 ? Icons.brightness_low_rounded : Icons.brightness_6_rounded)
                            : (_value < 0.05 ? Icons.volume_off_rounded : Icons.volume_up_rounded),
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 88,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: _value,
                            minHeight: 4,
                            backgroundColor: Colors.white.withValues(alpha: 0.15),
                            color: _isBrightness ? Colors.amber.shade300 : kPlayerAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 片尾倒计时自动下一集
class PlayerAutoNextCountdown extends StatefulWidget {
  final String nextLabel;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final int seconds;

  const PlayerAutoNextCountdown({
    super.key,
    required this.nextLabel,
    required this.onConfirm,
    required this.onCancel,
    this.seconds = 3,
  });

  @override
  State<PlayerAutoNextCountdown> createState() => _PlayerAutoNextCountdownState();
}

class _PlayerAutoNextCountdownState extends State<PlayerAutoNextCountdown> {
  late int _left;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _left = widget.seconds;
    _t = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_left <= 1) {
        timer.cancel();
        widget.onConfirm();
        return;
      }
      setState(() => _left -= 1);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Container(
          width: 280,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          decoration: BoxDecoration(
            color: const Color(0xF21A1D24),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$_left 秒后播放下一集',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                widget.nextLabel,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _t?.cancel();
                        widget.onCancel();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        _t?.cancel();
                        widget.onConfirm();
                      },
                      style: FilledButton.styleFrom(backgroundColor: kPlayerPrimary),
                      child: const Text('立即播放'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
