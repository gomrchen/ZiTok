import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/drama_models.dart';
import '../../providers/drama_provider.dart';
import 'android_system_pip.dart';
import 'player_extras.dart';
import 'player_handle.dart';
import 'player_runtime.dart';
import 'unlock_sheet.dart';

/// 无有效可播地址或服务端标记锁定
bool isPlayInfoBlocked(PlayInfo info, {String fallbackUrl = ''}) {
  if (info.locked || !info.canPlay) return true;
  return resolvePlayUrl(info, fallbackUrl).isEmpty;
}

String resolvePlayUrl(PlayInfo info, String fallbackUrl) {
  final primary = info.videoUrl.trim();
  if (primary.isNotEmpty) return primary;
  return fallbackUrl.trim();
}

/// Feed：HLS 走 media_kit，渐进式吃预热缓存；全集：优先 media_kit
enum EpisodeOpenMode { feed, full }

class EpisodePrepareOutcome {
  final bool cancelled;
  final String? error;
  final bool locked;
  final PlayInfo? info;
  final String url;

  const EpisodePrepareOutcome._({
    this.cancelled = false,
    this.error,
    this.locked = false,
    this.info,
    this.url = '',
  });

  factory EpisodePrepareOutcome.cancelled() =>
      const EpisodePrepareOutcome._(cancelled: true);
  factory EpisodePrepareOutcome.fail(String message) =>
      EpisodePrepareOutcome._(error: message);
  factory EpisodePrepareOutcome.lock(PlayInfo info) =>
      EpisodePrepareOutcome._(locked: true, info: info);
  factory EpisodePrepareOutcome.ready(PlayInfo info, String url) =>
      EpisodePrepareOutcome._(info: info, url: url);

  bool get isReady => !cancelled && error == null && !locked && url.isNotEmpty;
}

/// 网络守卫 + playInfo + 锁定/URL 解析（两页 _prepare 共用前半段）
Future<EpisodePrepareOutcome> prepareEpisodePlayback({
  required BuildContext context,
  required DramaProvider dp,
  required int episodeId,
  required String fallbackUrl,
  required bool Function() isMounted,
}) async {
  final netOk = await PlayerNetworkGuard.ensureCanPlay(context);
  if (!isMounted()) return EpisodePrepareOutcome.cancelled();
  if (!netOk) return EpisodePrepareOutcome.fail('网络不可用');

  final info = await dp.loadPlayInfo(episodeId);
  if (!isMounted()) return EpisodePrepareOutcome.cancelled();
  if (info == null) return EpisodePrepareOutcome.fail('加载失败');
  if (isPlayInfoBlocked(info, fallbackUrl: fallbackUrl)) {
    return EpisodePrepareOutcome.lock(info);
  }
  return EpisodePrepareOutcome.ready(info, resolvePlayUrl(info, fallbackUrl));
}

Future<PlayHandle> openEpisodePlayHandle({
  required String url,
  required int episodeId,
  required EpisodeOpenMode mode,
}) async {
  if (mode == EpisodeOpenMode.full) {
    unawaited(EpisodeVideoPreload.warm(episodeId: episodeId, url: url));
    return openPlayHandle(url, preferMediaKit: true);
  }
  final preferMk = url.toLowerCase().contains('m3u8');
  if (preferMk) {
    return openPlayHandle(url, preferMediaKit: true);
  }
  final taken = EpisodeVideoPreload.take(episodeId: episodeId, url: url);
  if (taken != null) {
    if (!taken.value.isInitialized) await taken.initialize();
    return VpPlayHandle(taken);
  }
  unawaited(EpisodeVideoPreload.warm(episodeId: episodeId, url: url));
  return openPlayHandle(url, preferMediaKit: false);
}

Future<void> applyPlayHandlePrefs(
  PlayHandle handle, {
  required bool muted,
  required double speed,
}) async {
  await handle.setLooping(false);
  await handle.setVolume(muted ? 0 : 1);
  await handle.setPlaybackSpeed(speed);
}

/// 尝试进入系统 PiP；返回是否成功
Future<bool> tryEnterSystemPip(
  BuildContext context, {
  String? unsupportedHint,
  String failHint = '当前设备暂不支持系统画中画',
  String okHint = '已进入系统画中画',
}) async {
  if (!AndroidSystemPip.isSupported) {
    if (context.mounted) {
      showPlayerTip(context, unsupportedHint ?? failHint);
    }
    return false;
  }
  final ok = await AndroidSystemPip.enter();
  if (!context.mounted) return false;
  if (!ok) {
    showPlayerTip(context, failHint);
    return false;
  }
  showPlayerTip(context, okHint, duration: const Duration(milliseconds: 1200));
  return true;
}

Future<bool> presentEpisodeUnlockSheet(
  BuildContext context, {
  required int episodeId,
  required int unlockPrice,
  required int bundlePrice,
  required int dramaId,
  DramaProvider? refreshWalletWith,
}) async {
  final ok = await showUnlockSheet(
    context,
    episodeId: episodeId,
    unlockPrice: unlockPrice,
    bundlePrice: bundlePrice,
    dramaId: dramaId,
  );
  if (ok == true && refreshWalletWith != null) {
    await refreshWalletWith.refreshWallet();
  }
  return ok == true;
}

Future<int?> resumeEpisodeIfNeeded({
  required PlayHandle player,
  required DramaProvider dp,
  required int episodeId,
  required bool Function() isMounted,
}) {
  final cloud = dp.continueList.map(
    (e) => (episodeId: e.resumeEpisodeId, positionSec: e.positionSec),
  );
  return PlayerProgressStore.seekIfNeeded(
    player: player,
    episodeId: episodeId,
    cloudHints: cloud,
    isMounted: isMounted,
  );
}

/// 播放页共用轻量提示（暗色浮层）
void showPlayerTip(
  BuildContext context,
  String message, {
  Duration duration = const Duration(milliseconds: 1400),
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: duration,
    ),
  );
}

/// 追剧切换；成功返回新状态，失败返回 null（调用方回滚 UI）
Future<bool?> toggleDramaFavorite({
  required DramaProvider dp,
  required int dramaId,
  required bool currentlyFav,
}) async {
  try {
    await dp.toggleFavorite(dramaId, currentlyFav: currentlyFav);
    return !currentlyFav;
  } catch (_) {
    return null;
  }
}

void reportEpisodeProgress({
  required DramaProvider dp,
  required FeedItem item,
  required PlayHandle? player,
}) {
  final sec = player?.isInitialized == true ? player!.position.inSeconds : 0;
  unawaited(dp.reportProgress(item, positionSec: sec));
  unawaited(PlayerProgressStore.save(
    episodeId: item.episode.id,
    positionSec: sec,
  ));
}

/// 预热下一集；[fallbackUrl] 为列表里的兜底直链
Future<void> warmNextEpisode({
  required DramaProvider dp,
  required int episodeId,
  required String fallbackUrl,
  required bool Function() isMounted,
}) async {
  if (!isMounted()) return;
  try {
    final info = await dp.loadPlayInfo(episodeId);
    if (!isMounted()) return;
    final url = (info?.videoUrl.isNotEmpty == true) ? info!.videoUrl : fallbackUrl;
    if (url.isEmpty || info?.locked == true) return;
    await EpisodeVideoPreload.warm(episodeId: episodeId, url: url);
  } catch (_) {}
}

/// 弹出倍速表并应用到句柄；成功返回新倍速
Future<double?> pickPlaybackSpeed(
  BuildContext context, {
  required PlayHandle? player,
  required double current,
}) async {
  if (player == null || !player.isInitialized) return null;
  final picked = await showPlayerSpeedSheet(context, current: current);
  if (picked == null) return null;
  await player.setPlaybackSpeed(picked);
  return picked;
}

Future<void> syncPlayerWakeLock({
  required int holderId,
  required bool active,
  required bool paused,
  required bool locked,
  required PlayHandle? player,
  required bool systemPipBound,
}) async {
  final playing =
      active && !paused && !locked && (player?.isPlaying ?? false);
  await PlayerWakelock.sync(holder: holderId, keepOn: playing);
  if (systemPipBound) {
    await AndroidSystemPip.syncPlaying(playing);
  }
}

Future<void> pausePlayerForOverlay({
  required PlayHandle? player,
  required VoidCallback markPaused,
  required Future<void> Function() syncWake,
}) async {
  await player?.pause();
  markPaused();
  await syncWake();
}

Future<void> resumePlayerIfActive({
  required PlayHandle? player,
  required bool active,
  required bool locked,
  required VoidCallback markPlaying,
  required Future<void> Function() syncWake,
  bool skip = false,
}) async {
  if (!active || locked || skip) return;
  await player?.play();
  markPlaying();
  await syncWake();
}

Future<void> animateToNextPage(PageController controller) {
  return controller.nextPage(
    duration: const Duration(milliseconds: 320),
    curve: Curves.easeOutCubic,
  );
}

/// Android 系统 PiP 会话：绑定/解绑与可选 inPip 监听
class SystemPipSession {
  bool bound = false;
  VoidCallback? _pipListener;

  void bind({
    required VoidCallback onPlay,
    required VoidCallback onPause,
    VoidCallback? onPipChanged,
  }) {
    if (!AndroidSystemPip.isSupported || bound) return;
    AndroidSystemPip.bindPlayer(onPlay: onPlay, onPause: onPause);
    if (onPipChanged != null) {
      _pipListener = onPipChanged;
      AndroidSystemPip.inPip.addListener(onPipChanged);
    }
    unawaited(AndroidSystemPip.preferAutoEnter(enable: true));
    bound = true;
  }

  void unbind() {
    if (!bound) return;
    final listener = _pipListener;
    if (listener != null) {
      AndroidSystemPip.inPip.removeListener(listener);
      _pipListener = null;
    }
    AndroidSystemPip.unbindPlayer();
    unawaited(AndroidSystemPip.preferAutoEnter(enable: false));
    bound = false;
  }
}
