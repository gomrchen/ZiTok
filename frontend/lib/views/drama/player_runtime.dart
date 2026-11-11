import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'media_url.dart';
import 'player_handle.dart';

/// 播放中保持屏幕常亮（多 slide 用 holder 引用，避免快切竞态）
class PlayerWakelock {
  static bool _enabled = false;
  static final Set<Object> _holders = <Object>{};

  /// [holder] 建议用 episodeId；keepOn=false 时移除该 holder
  static Future<void> sync({required Object holder, required bool keepOn}) async {
    if (keepOn) {
      _holders.add(holder);
    } else {
      _holders.remove(holder);
    }
    await _apply();
  }

  /// 页面退出时清空全部 holder
  static Future<void> clearAll() async {
    _holders.clear();
    await _apply();
  }

  static Future<void> _apply() async {
    final want = _holders.isNotEmpty;
    if (want == _enabled) return;
    try {
      if (want) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
      _enabled = want;
    } catch (_) {}
  }
}

/// 蜂窝流量提醒 + 离线提示（移动网络会话内只提示一次）
class PlayerNetworkGuard {
  static bool _mobileTipShown = false;

  static Future<bool> ensureCanPlay(BuildContext context) async {
    List<ConnectivityResult> results;
    try {
      results = await Connectivity().checkConnectivity();
    } catch (_) {
      return true;
    }

    final offline = results.isEmpty ||
        results.every((e) => e == ConnectivityResult.none);
    if (offline) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('当前无网络，请检查连接后重试'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return false;
    }

    final hasWifiLike = results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet);
    final mobile = results.contains(ConnectivityResult.mobile) && !hasWifiLike;
    if (mobile && !_mobileTipShown && context.mounted) {
      _mobileTipShown = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('正在使用移动网络播放，请注意流量消耗'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
    return true;
  }

  static DateTime? _lastSlowTipAt;

  static void tipSlowIfNeeded(BuildContext context, Duration elapsed) {
    if (elapsed < const Duration(seconds: 6) || !context.mounted) return;
    final now = DateTime.now();
    if (_lastSlowTipAt != null && now.difference(_lastSlowTipAt!) < const Duration(seconds: 20)) {
      return;
    }
    _lastSlowTipAt = now;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('网络较慢，正在努力加载…'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class _PreloadedPlayer {
  final String url;
  final VideoPlayerController controller;
  _PreloadedPlayer({required this.url, required this.controller});
}

/// 下一集预热：渐进式视频走文件缓存，并预初始化播放器
/// 以 episodeId 为键，take 时校验 URL，避免播错源
class EpisodeVideoPreload {
  static final Map<int, _PreloadedPlayer> _ready = {};
  static final Map<int, Future<void>> _inflight = {};
  static final CacheManager _cache = DefaultCacheManager();

  static Future<void> warm({
    required int episodeId,
    required String url,
  }) async {
    final trimmed = sanitizeHttpMediaUrl(url);
    if (trimmed == null || episodeId <= 0) return;
    final hit = _ready[episodeId];
    if (hit != null && hit.url == trimmed) return;
    if (_inflight.containsKey(episodeId)) {
      await _inflight[episodeId];
      return;
    }
    final fut = _doWarm(episodeId, trimmed);
    _inflight[episodeId] = fut;
    try {
      await fut;
    } finally {
      _inflight.remove(episodeId);
    }
  }

  static Future<void> _doWarm(int episodeId, String url) async {
    try {
      late final VideoPlayerController c;
      if (isProgressiveVideoUrl(url)) {
        try {
          final file = await _cache.getSingleFile(url);
          c = VideoPlayerController.file(file);
        } catch (_) {
          c = VideoPlayerController.networkUrl(Uri.parse(url));
        }
      } else {
        c = VideoPlayerController.networkUrl(Uri.parse(url));
      }
      await c.initialize();
      await c.setLooping(false);
      await c.setVolume(0);
      await c.pause();
      final old = _ready.remove(episodeId);
      await old?.controller.dispose();
      _ready[episodeId] = _PreloadedPlayer(url: url, controller: c);
      _trim(keep: episodeId);
    } catch (_) {}
  }

  static void _trim({required int keep}) {
    while (_ready.length > 2) {
      final extra = _ready.keys.firstWhere((e) => e != keep, orElse: () => -1);
      if (extra < 0) break;
      final c = _ready.remove(extra);
      c?.controller.dispose();
    }
  }

  /// 取出已预热控制器；URL 不一致则丢弃重开。调用方负责 dispose
  static VideoPlayerController? take({
    required int episodeId,
    required String url,
  }) {
    final hit = _ready.remove(episodeId);
    if (hit == null) return null;
    if (hit.url != url.trim()) {
      hit.controller.dispose();
      return null;
    }
    return hit.controller;
  }

  /// 打开播放：优先本地缓存文件，否则网络
  static Future<VideoPlayerController> openController(String url) async {
    final trimmed = sanitizeHttpMediaUrl(url);
    if (trimmed == null) throw StateError('invalid url');
    if (isProgressiveVideoUrl(trimmed)) {
      try {
        final file = await _cache.getSingleFile(trimmed);
        if (await file.exists()) {
          return VideoPlayerController.file(File(file.path));
        }
      } catch (_) {}
    }
    return VideoPlayerController.networkUrl(Uri.parse(trimmed));
  }

  static Future<void> discardAll() async {
    final all = List<_PreloadedPlayer>.from(_ready.values);
    _ready.clear();
    _inflight.clear();
    for (final e in all) {
      await e.controller.dispose();
    }
  }
}

/// 本机续播进度（未登录/服务端滞后时兜底）
class PlayerProgressStore {
  static const _prefix = 'drama_pos_';

  static Future<void> save({required int episodeId, required int positionSec}) async {
    if (episodeId <= 0 || positionSec < 3) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('$_prefix$episodeId', positionSec);
    } catch (_) {}
  }

  static Future<int> load(int episodeId) async {
    if (episodeId <= 0) return 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('$_prefix$episodeId') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// 结合本机缓存与在追列表，取较大有效进度
  static Future<int> resolveResumeSec({
    required int episodeId,
    required Iterable<({int episodeId, int positionSec})> cloudHints,
  }) async {
    var best = await load(episodeId);
    for (final h in cloudHints) {
      if (h.episodeId == episodeId && h.positionSec > best) {
        best = h.positionSec;
      }
    }
    return best;
  }

  static String formatClock(int sec) {
    final s = sec < 0 ? 0 : sec;
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  /// 解析进度并 seek；返回实际续播秒数，无需续播时返回 null
  static Future<int?> seekIfNeeded({
    required PlayHandle player,
    required int episodeId,
    required Iterable<({int episodeId, int positionSec})> cloudHints,
    bool Function()? isMounted,
  }) async {
    final sec = await resolveResumeSec(episodeId: episodeId, cloudHints: cloudHints);
    if (sec < 5) return null;
    for (var i = 0; i < 20; i++) {
      if (isMounted != null && !isMounted()) return null;
      if (player.duration.inSeconds > 0) break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (isMounted != null && !isMounted()) return null;
    final dur = player.duration.inSeconds;
    if (dur > 0 && sec >= dur - 3) return null;
    try {
      await player.seekTo(Duration(seconds: sec));
      return sec;
    } catch (_) {
      return null;
    }
  }
}
