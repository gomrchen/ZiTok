import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'player_handle.dart';

class DanmakuItem {
  final String text;
  final Color color;
  /// 相对视频时间轴（毫秒）；null 表示自由轮播
  final int? atMs;
  const DanmakuItem(this.text, {this.color = Colors.white, this.atMs});
}

/// 真弹幕层：优先按播放进度触发，其余自由轮播；随 paused/enabled 启停
class PlayerDanmakuLayer extends StatefulWidget {
  final List<DanmakuItem> items;
  final PlayHandle? handle;
  final bool enabled;
  final bool paused;
  final double speed;

  const PlayerDanmakuLayer({
    super.key,
    required this.items,
    this.handle,
    this.enabled = true,
    this.paused = false,
    this.speed = 90,
  });

  @override
  State<PlayerDanmakuLayer> createState() => _PlayerDanmakuLayerState();
}

class _PlayerDanmakuLayerState extends State<PlayerDanmakuLayer>
    with SingleTickerProviderStateMixin {
  static const _trackCount = 8;
  static const _trackGap = 28.0;
  static const _spawnMs = 900;
  static const _maxFlying = 36;
  static const _maxChars = 22;

  late final AnimationController _tick;
  final _rand = math.Random();
  final List<_Flying> _flying = [];
  final List<DateTime> _trackFreeAt =
      List.generate(_trackCount, (_) => DateTime.fromMillisecondsSinceEpoch(0));
  final Set<int> _firedTimed = {};
  int _cursor = 0;
  Timer? _spawn;
  List<DanmakuItem> _freeItems = const [];
  List<DanmakuItem> _timedItems = const [];

  bool get _running => widget.enabled && !widget.paused && widget.items.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _splitItems();
    _tick = AnimationController(vsync: this, duration: const Duration(hours: 1))
      ..addListener(() {
        if (mounted && _running) setState(() {});
      });
    widget.handle?.addListener(_onPlayer);
    _syncLifecycle(spawnNow: true);
  }

  @override
  void didUpdateWidget(covariant PlayerDanmakuLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.handle != widget.handle) {
      oldWidget.handle?.removeListener(_onPlayer);
      widget.handle?.addListener(_onPlayer);
    }
    final enabledChanged = oldWidget.enabled != widget.enabled;
    final pausedChanged = oldWidget.paused != widget.paused;
    final itemsChanged = !identical(oldWidget.items, widget.items);

    if (pausedChanged) {
      if (widget.paused) {
        _freezeAll();
      } else if (oldWidget.paused) {
        _unfreezeAll();
      }
    }
    if (!widget.enabled && oldWidget.enabled) {
      _flying.clear();
      _firedTimed.clear();
      for (var i = 0; i < _trackCount; i++) {
        _trackFreeAt[i] = DateTime.fromMillisecondsSinceEpoch(0);
      }
    }
    if (itemsChanged) {
      _cursor = 0;
      _firedTimed.clear();
      _splitItems();
    }
    _syncLifecycle(spawnNow: enabledChanged && widget.enabled);
  }

  void _splitItems() {
    _timedItems = widget.items.where((e) => e.atMs != null).toList()
      ..sort((a, b) => a.atMs!.compareTo(b.atMs!));
    _freeItems = widget.items.where((e) => e.atMs == null).toList();
  }

  void _onPlayer() {
    if (!_running) return;
    _fireTimed();
  }

  void _fireTimed() {
    final h = widget.handle;
    if (h == null || !h.isInitialized || _timedItems.isEmpty) return;
    final pos = h.position.inMilliseconds;
    for (var i = 0; i < _timedItems.length; i++) {
      if (_firedTimed.contains(i)) continue;
      final at = _timedItems[i].atMs!;
      if (pos + 80 >= at) {
        _firedTimed.add(i);
        _emit(_timedItems[i]);
      }
    }
    // seek 回退：清掉未来已触发标记
    _firedTimed.removeWhere((i) {
      final at = _timedItems[i].atMs!;
      return at > pos + 400;
    });
  }

  void _freezeAll() {
    final now = DateTime.now();
    for (final f in _flying) {
      f.frozenElapsed = now.difference(f.born);
    }
  }

  void _unfreezeAll() {
    final now = DateTime.now();
    for (final f in _flying) {
      final e = f.frozenElapsed;
      if (e != null) {
        f.born = now.subtract(e);
        f.frozenElapsed = null;
      }
    }
  }

  void _syncLifecycle({bool spawnNow = false}) {
    _spawn?.cancel();
    _spawn = null;
    if (!_running) {
      if (_tick.isAnimating) _tick.stop();
      return;
    }
    if (!_tick.isAnimating) _tick.repeat();
    if (spawnNow) {
      _fireTimed();
      if (_freeItems.isNotEmpty) _spawnFree();
    }
    if (_freeItems.isNotEmpty) {
      _spawn = Timer.periodic(const Duration(milliseconds: _spawnMs), (_) => _spawnFree());
    }
  }

  int _pickTrack(DateTime now) {
    final free = <int>[];
    for (var i = 0; i < _trackCount; i++) {
      if (!_trackFreeAt[i].isAfter(now)) free.add(i);
    }
    if (free.isNotEmpty) return free[_rand.nextInt(free.length)];
    var best = 0;
    for (var i = 1; i < _trackCount; i++) {
      if (_trackFreeAt[i].isBefore(_trackFreeAt[best])) best = i;
    }
    return best;
  }

  String _clip(String raw) {
    final t = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.length <= _maxChars) return t;
    return '${t.substring(0, _maxChars)}…';
  }

  void _spawnFree() {
    if (!mounted || !_running || _freeItems.isEmpty) return;
    final item = _freeItems[_cursor % _freeItems.length];
    _cursor++;
    _emit(item);
  }

  void _emit(DanmakuItem item) {
    final text = _clip(item.text);
    if (text.isEmpty || !mounted) return;
    final now = DateTime.now();
    final estWidth = 16.0 + text.length * 14.0;
    final screenW = MediaQuery.sizeOf(context).width;
    final track = _pickTrack(now);
    final holdSec = (screenW * 0.55 + 40) / widget.speed;
    _trackFreeAt[track] = now.add(Duration(milliseconds: (holdSec * 1000).round()));
    _flying.add(
      _Flying(
        text: text,
        color: item.color,
        track: track,
        born: now,
        width: estWidth,
      ),
    );
    if (_flying.length > _maxFlying) {
      _flying.removeRange(0, _flying.length - _maxFlying);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _spawn?.cancel();
    widget.handle?.removeListener(_onPlayer);
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();
    final w = MediaQuery.sizeOf(context).width;
    final topPad = MediaQuery.paddingOf(context).top + 72;
    final now = DateTime.now();

    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final f in List<_Flying>.from(_flying))
            Builder(
              builder: (_) {
                final elapsed = f.frozenElapsed ?? now.difference(f.born);
                final sec = elapsed.inMilliseconds / 1000.0;
                final x = w - sec * widget.speed;
                if (x < -f.width) return const SizedBox.shrink();
                return Positioned(
                  left: x,
                  top: topPad + f.track * _trackGap,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: w * 0.78),
                    child: Text(
                      f.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: f.color,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        shadows: const [
                          Shadow(color: Color(0xCC000000), blurRadius: 4, offset: Offset(0, 1)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _Flying {
  final String text;
  final Color color;
  final int track;
  final double width;
  DateTime born;
  Duration? frozenElapsed;

  _Flying({
    required this.text,
    required this.color,
    required this.track,
    required this.born,
    required this.width,
  });
}
