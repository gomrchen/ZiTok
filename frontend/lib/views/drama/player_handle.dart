import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:video_player/video_player.dart' hide VideoTrack;

import '../../widgets/cover_video.dart';
import 'media_url.dart';
import 'player_cast_quality.dart';

/// 统一播放句柄：屏蔽 video_player / media_kit 差异
abstract class PlayHandle {
  bool get isInitialized;
  bool get isPlaying;
  bool get isBuffering;
  Duration get position;
  Duration get duration;
  Size get size;
  String? get currentVideoTrackId => null;

  void addListener(VoidCallback listener);
  void removeListener(VoidCallback listener);

  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(Duration position);
  Future<void> setVolume(double volume);
  Future<void> setPlaybackSpeed(double speed);
  Future<void> setLooping(bool looping);
  Future<void> dispose();

  /// media_kit 等引擎内视频轨（HLS 多码率）
  List<VideoQualityOption> engineTrackOptions() => const [];
  Future<bool> selectEngineTrack(VideoQualityOption option) async => false;

  /// 引擎内嵌/外挂字幕（media_kit 直接烧到画面）
  bool get supportsEngineSubtitle => false;
  bool get hasEngineSubtitle => false;
  Future<void> setEngineSubtitle({required bool on, String? externalUrl}) async {}

  Widget buildCover();
}

/// 经典 video_player 实现（首页 Feed 等）
class VpPlayHandle implements PlayHandle {
  final VideoPlayerController controller;
  VpPlayHandle(this.controller);

  static Future<VpPlayHandle> open(String url) async {
    final trimmed = sanitizeHttpMediaUrl(url);
    if (trimmed == null) throw StateError('invalid url');
    VideoPlayerController c;
    if (isProgressiveVideoUrl(trimmed)) {
      try {
        final file = await DefaultCacheManager().getSingleFile(trimmed);
        c = VideoPlayerController.file(File(file.path));
      } catch (_) {
        c = VideoPlayerController.networkUrl(Uri.parse(trimmed));
      }
    } else {
      c = VideoPlayerController.networkUrl(Uri.parse(trimmed));
    }
    await c.initialize();
    await c.setLooping(false);
    return VpPlayHandle(c);
  }

  @override
  bool get isInitialized => controller.value.isInitialized;
  @override
  bool get isPlaying => controller.value.isPlaying;
  @override
  bool get isBuffering => controller.value.isBuffering;
  @override
  Duration get position => controller.value.position;
  @override
  Duration get duration => controller.value.duration;
  @override
  Size get size => controller.value.size;

  @override
  void addListener(VoidCallback listener) => controller.addListener(listener);
  @override
  void removeListener(VoidCallback listener) => controller.removeListener(listener);

  @override
  Future<void> play() => controller.play();
  @override
  Future<void> pause() => controller.pause();
  @override
  Future<void> seekTo(Duration position) => controller.seekTo(position);
  @override
  Future<void> setVolume(double volume) => controller.setVolume(volume.clamp(0.0, 1.0));
  @override
  Future<void> setPlaybackSpeed(double speed) => controller.setPlaybackSpeed(speed);
  @override
  Future<void> setLooping(bool looping) => controller.setLooping(looping);
  @override
  Future<void> dispose() => controller.dispose();

  @override
  String? get currentVideoTrackId => null;
  @override
  List<VideoQualityOption> engineTrackOptions() => const [];
  @override
  Future<bool> selectEngineTrack(VideoQualityOption option) async => false;
  @override
  bool get supportsEngineSubtitle => false;
  @override
  bool get hasEngineSubtitle => false;
  @override
  Future<void> setEngineSubtitle({required bool on, String? externalUrl}) async {}

  @override
  Widget buildCover() => CoverVideo(controller: controller);
}

/// media_kit 实现：更强 HLS / 多码率基础
class MkPlayHandle extends ChangeNotifier implements PlayHandle {
  final Player player;
  late final VideoController videoController;
  bool _ready = false;
  bool _looping = false;
  final List<StreamSubscription> _subs = [];

  String? _trackId = 'auto';
  bool _buffering = false;

  MkPlayHandle._(this.player) {
    videoController = VideoController(player);
    _subs.add(player.stream.playing.listen((_) => notifyListeners()));
    _subs.add(player.stream.position.listen((_) => notifyListeners()));
    _subs.add(player.stream.duration.listen((_) => notifyListeners()));
    _subs.add(player.stream.width.listen((_) => notifyListeners()));
    _subs.add(player.stream.height.listen((_) => notifyListeners()));
    _subs.add(player.stream.buffering.listen((v) {
      _buffering = v;
      notifyListeners();
    }));
    _subs.add(player.stream.tracks.listen((_) => notifyListeners()));
    _subs.add(player.stream.track.listen((t) {
      _trackId = t.video.id;
      notifyListeners();
    }));
    _subs.add(player.stream.completed.listen((done) {
      if (done && _looping) {
        player.seek(Duration.zero);
        player.play();
      }
      notifyListeners();
    }));
  }

  static Future<MkPlayHandle> open(String url) async {
    final trimmed = sanitizeHttpMediaUrl(url);
    if (trimmed == null) throw StateError('invalid url');
    final player = Player();
    final handle = MkPlayHandle._(player);
    await player.open(Media(trimmed), play: false);
    // 等到有时长或开始缓冲后再标 ready
    await player.stream.duration.first.timeout(
      const Duration(seconds: 20),
      onTimeout: () => Duration.zero,
    );
    handle._ready = true;
    handle.notifyListeners();
    return handle;
  }

  @override
  bool get isInitialized => _ready;
  @override
  bool get isPlaying => player.state.playing;
  @override
  bool get isBuffering => _buffering || player.state.buffering;
  @override
  Duration get position => player.state.position;
  @override
  Duration get duration => player.state.duration;
  @override
  String? get currentVideoTrackId => _trackId;
  @override
  Size get size {
    final w = player.state.width?.toDouble() ?? 0;
    final h = player.state.height?.toDouble() ?? 0;
    if (w <= 0 || h <= 0) return const Size(9, 16);
    return Size(w, h);
  }

  @override
  Future<void> play() => player.play();
  @override
  Future<void> pause() => player.pause();
  @override
  Future<void> seekTo(Duration position) => player.seek(position);
  @override
  Future<void> setVolume(double volume) => player.setVolume((volume.clamp(0.0, 1.0)) * 100);
  @override
  Future<void> setPlaybackSpeed(double speed) => player.setRate(speed);
  @override
  Future<void> setLooping(bool looping) async {
    _looping = looping;
  }

  @override
  List<VideoQualityOption> engineTrackOptions() {
    final vids = player.state.tracks.video;
    if (vids.isEmpty) return const [];
    final out = <VideoQualityOption>[];
    for (final t in vids) {
      if (t.id == 'no') continue;
      String label;
      if (t.id == 'auto') {
        label = '自动 · 引擎';
      } else if (t.title != null && t.title!.trim().isNotEmpty) {
        label = t.title!.trim();
      } else if (t.h != null && t.h! > 0) {
        label = '${t.h}p';
      } else {
        label = '轨 ${t.id}';
      }
      out.add(VideoQualityOption(label: label, url: '', isHls: true, trackId: t.id));
    }
    return out;
  }

  @override
  Future<bool> selectEngineTrack(VideoQualityOption option) async {
    final id = option.trackId;
    if (id == null || id.isEmpty) return false;
    VideoTrack? hit;
    for (final t in player.state.tracks.video) {
      if (t.id == id) {
        hit = t;
        break;
      }
    }
    hit ??= id == 'auto' ? VideoTrack.auto() : null;
    if (hit == null) return false;
    await player.setVideoTrack(hit);
    _trackId = hit.id;
    notifyListeners();
    return true;
  }

  @override
  bool get supportsEngineSubtitle => true;

  @override
  bool get hasEngineSubtitle {
    final subs = player.state.tracks.subtitle;
    return subs.any((e) => e.id != 'no' && e.id != 'auto') || subs.any((e) => e.uri || e.data);
  }

  @override
  Future<void> setEngineSubtitle({required bool on, String? externalUrl}) async {
    if (!on) {
      await player.setSubtitleTrack(SubtitleTrack.no());
      notifyListeners();
      return;
    }
    final ext = sanitizeHttpMediaUrl(externalUrl);
    if (ext != null) {
      await player.setSubtitleTrack(SubtitleTrack.uri(ext, title: '外挂字幕'));
      notifyListeners();
      return;
    }
    // 优先选非 auto/no 的内嵌轨
    SubtitleTrack? hit;
    for (final t in player.state.tracks.subtitle) {
      if (t.id != 'auto' && t.id != 'no') {
        hit = t;
        break;
      }
    }
    await player.setSubtitleTrack(hit ?? SubtitleTrack.auto());
    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await player.dispose();
    super.dispose();
  }

  @override
  Widget buildCover() {
    if (!_ready) return const ColoredBox(color: Colors.black);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        if (!maxW.isFinite || !maxH.isFinite || maxW <= 0 || maxH <= 0) {
          return const ColoredBox(color: Colors.black);
        }
        final sz = size;
        final scale = math.max(maxW / sz.width, maxH / sz.height);
        final w = sz.width * scale;
        final h = sz.height * scale;
        return ClipRect(
          child: ColoredBox(
            color: Colors.black,
            child: OverflowBox(
              alignment: Alignment.center,
              minWidth: w,
              minHeight: h,
              maxWidth: w,
              maxHeight: h,
              child: SizedBox(
                width: w,
                height: h,
                child: Video(
                  controller: videoController,
                  controls: NoVideoControls,
                  fill: Colors.black,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 剧集页优先 media_kit（HLS/多码率更好）；失败回退 video_player
Future<PlayHandle> openPlayHandle(String url, {bool preferMediaKit = true}) async {
  final u = sanitizeHttpMediaUrl(url);
  if (u == null) throw StateError('invalid url');
  if (preferMediaKit) {
    try {
      return await MkPlayHandle.open(u);
    } catch (_) {
      return VpPlayHandle.open(u);
    }
  }
  return VpPlayHandle.open(u);
}
