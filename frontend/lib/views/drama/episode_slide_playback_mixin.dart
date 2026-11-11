import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/drama_models.dart';
import '../../providers/drama_provider.dart';
import '../../providers/settings_provider.dart';
import 'episode_engagement.dart';
import 'media_url.dart';
import 'player_danmaku.dart';
import 'player_gesture.dart';
import 'player_handle.dart';
import 'player_runtime.dart';
import 'player_session.dart';

/// Feed / 全集 `_EpisodeSlideState` 共用：进度、互动、手势、PiP 绑定（不含 build / 开流差异）
mixin EpisodeSlidePlaybackMixin<T extends StatefulWidget> on State<T> {
  PlayHandle? player;
  bool locked = false;
  bool loading = true;
  bool paused = false;
  bool showPauseHint = false;
  bool liked = false;
  bool favorited = false;
  bool speedUp = false;
  bool endedHandled = false;
  bool awaitingNext = false;
  bool danmakuOn = false;
  bool muted = false;
  double baseSpeed = 1.0;
  int likeCount = 0;
  int commentCount = 0;
  String? error;
  List<DanmakuItem> danmakuItems = const [];
  Timer? progressTimer;
  Timer? tapTimer;
  final LikeBurstSession burst = LikeBurstSession();
  final SystemPipSession systemPip = SystemPipSession();

  // —— Host 契约 ——
  int get slideEpisodeId;
  int get slideDramaId;
  int get slideEpisodeNo;
  int get slideUnlockPrice;
  int get slideBundlePrice;
  int get slideInitialLikeCount;
  bool get slideActive;
  bool get slideFavorited;
  bool get slideHasNext;
  FeedItem get slideProgressItem;
  int? get slideWarmNextEpisodeId;
  String get slideWarmNextFallbackUrl;
  VoidCallback get slideOnEnded;

  /// 激活时是否还要检查 locked（全集 true）
  bool get slideRespectLockOnActivate => false;

  VoidCallback? get slideOnSystemPipChanged => null;

  /// 片尾接近回调（全集用于下一集气泡）
  void slideOnNearEndChanged(bool near) {}

  String get slideVideoFallbackUrl;
  EpisodeOpenMode get slideOpenMode;
  bool get slideShowResumeTip => false;

  /// 基础 prepare 重置（在 setState 内调用）
  void slideResetPrepareUi() {
    loading = true;
    error = null;
    endedHandled = false;
    danmakuItems = const [];
  }

  /// 全集额外重置字幕/倍速等
  void slideResetPrepareUiExtra() {}

  /// playInfo 就绪后：全集写清晰度/字幕
  Future<void> slideOnPlayInfoReady(PlayInfo info, String url) async {}

  /// 认领小窗还原句柄；无则 null
  Future<PlayHandle?> slideClaimExistingPlayer() async => null;

  /// 是否跳过续播 seek（小窗还原等）
  bool slideSkipResumeAfterOpen(PlayHandle c) => false;

  Future<void> prepareEpisodeSlide({required VoidCallback onNeedUnlock}) async {
    setState(() {
      slideResetPrepareUi();
      slideResetPrepareUiExtra();
    });
    player?.removeListener(onVideoTick);
    await player?.dispose();
    player = null;
    if (!mounted) return;
    final dp = context.read<DramaProvider>();
    try {
      final gate = await prepareEpisodePlayback(
        context: context,
        dp: dp,
        episodeId: slideEpisodeId,
        fallbackUrl: slideVideoFallbackUrl,
        isMounted: () => mounted,
      );
      if (!mounted || gate.cancelled) return;
      if (gate.error != null) {
        setState(() {
          error = gate.error;
          loading = false;
        });
        return;
      }
      if (gate.locked) {
        setState(() {
          locked = true;
          loading = false;
        });
        if (slideActive) {
          WidgetsBinding.instance.addPostFrameCallback((_) => onNeedUnlock());
        }
        return;
      }
      final info = gate.info!;
      final url = gate.url;
      await slideOnPlayInfoReady(info, url);
      if (!mounted) return;

      final sw = Stopwatch()..start();
      var c = await slideClaimExistingPlayer();
      if (c == null) {
        c = await openEpisodePlayHandle(
          url: url,
          episodeId: slideEpisodeId,
          mode: slideOpenMode,
        );
        if (mounted) PlayerNetworkGuard.tipSlowIfNeeded(context, sw.elapsed);
        await applyPlayHandlePrefs(c, muted: muted, speed: baseSpeed);
      }
      c.addListener(onVideoTick);
      if (!mounted) {
        await c.dispose();
        return;
      }
      player = c;

      if (!slideSkipResumeAfterOpen(c) && slideActive) {
        await maybeResumePosition(c, dp, tip: slideShowResumeTip);
      }
      if (slideActive) {
        await c.play();
        await syncWake();
        unawaited(warmNext());
      }
      setState(() {
        loading = false;
        likeCount = slideInitialLikeCount;
      });
      await Future.wait([syncLikeStatus(), syncCommentCount()]);
      if (danmakuOn) unawaited(loadDanmaku());
      if (slideActive) startProgressTimer();
    } catch (e) {
      if (mounted) {
        setState(() {
          error = playerFriendlyError(e);
          loading = false;
        });
      }
    }
  }

  void slideInitPlayback() {
    favorited = slideFavorited;
    if (slideActive) bindSystemPip();
  }

  void slideHandleActiveChanged({
    required bool wasActive,
    required bool nowActive,
    required bool favoritedChanged,
    required bool newFavorited,
  }) {
    if (favoritedChanged) favorited = newFavorited;
    if (nowActive && !wasActive) {
      endedHandled = false;
      awaitingNext = false;
      slideOnBecameActiveExtraReset();
      final canPlay = !paused && (!slideRespectLockOnActivate || !locked);
      if (canPlay) player?.play();
      startProgressTimer();
      syncWake();
      unawaited(warmNext());
      bindSystemPip();
    } else if (!nowActive && wasActive) {
      unbindSystemPip();
      player?.pause();
      stopProgressTimer();
      if (speedUp) {
        player?.setPlaybackSpeed(baseSpeed);
        speedUp = false;
      }
      awaitingNext = false;
      PlayerWakelock.sync(holder: slideEpisodeId, keepOn: false);
    }
  }

  /// 全集额外重置 _nearEnd 等
  void slideOnBecameActiveExtraReset() {}

  void bindSystemPip() {
    systemPip.bind(
      onPlay: () {
        unawaited(player?.play());
        if (mounted) setState(() => paused = false);
        unawaited(syncWake());
      },
      onPause: () {
        unawaited(player?.pause());
        if (mounted) setState(() => paused = true);
        unawaited(syncWake());
      },
      onPipChanged: slideOnSystemPipChanged,
    );
  }

  void unbindSystemPip() => systemPip.unbind();

  Future<void> syncWake() => syncPlayerWakeLock(
        holderId: slideEpisodeId,
        active: slideActive,
        paused: paused,
        locked: locked,
        player: player,
        systemPipBound: systemPip.bound,
      );

  Future<void> warmNext() async {
    final id = slideWarmNextEpisodeId;
    if (id == null) return;
    await warmNextEpisode(
      dp: context.read<DramaProvider>(),
      episodeId: id,
      fallbackUrl: slideWarmNextFallbackUrl,
      isMounted: () => mounted,
    );
  }

  void startProgressTimer() {
    progressTimer?.cancel();
    progressTimer = Timer.periodic(const Duration(seconds: 5), (_) => reportProgressNow());
  }

  void stopProgressTimer() {
    progressTimer?.cancel();
    progressTimer = null;
  }

  void reportProgressNow() {
    if (!mounted) return;
    reportEpisodeProgress(
      dp: context.read<DramaProvider>(),
      item: slideProgressItem,
      player: player,
    );
  }

  void onVideoTick() {
    if (!mounted) return;
    final c = player;
    if (c == null || !c.isInitialized) return;

    final near = isNearEpisodeEnd(
      position: c.position,
      duration: c.duration,
      hasNext: slideHasNext,
    );
    slideOnNearEndChanged(near);

    final decision = evaluateEpisodeEnd(
      position: c.position,
      duration: c.duration,
      endedHandled: endedHandled,
      active: slideActive,
      hasNext: slideHasNext,
      useCountdown: context.read<SettingsProvider>().autoNextCountdown,
    );
    if (decision == EpisodeEndDecision.ignore) return;
    endedHandled = true;
    reportProgressNow();
    if (decision == EpisodeEndDecision.countdown) {
      setState(() => awaitingNext = true);
    } else {
      slideOnEnded();
    }
  }

  Future<void> loadDanmaku() async {
    final texts = await EpisodeEngagement.fetchCommentTexts(slideEpisodeId);
    if (!mounted) return;
    if (texts == null) {
      if (danmakuOn) {
        showPlayerTip(context, '弹幕加载失败', duration: const Duration(milliseconds: 1200));
      }
      return;
    }
    setState(() {
      danmakuItems = EpisodeEngagement.buildDanmakuItems(
        texts: texts,
        episodeNo: slideEpisodeNo,
        durationMs: player?.duration.inMilliseconds ?? 0,
      );
    });
  }

  Future<void> syncLikeStatus() async {
    final snap = await EpisodeEngagement.fetchLikeStatus(slideEpisodeId);
    if (!mounted || snap == null) return;
    setState(() {
      liked = snap.liked;
      likeCount = snap.likeCount;
    });
  }

  Future<void> syncCommentCount() async {
    final total = await EpisodeEngagement.fetchCommentTotal(slideEpisodeId);
    if (!mounted || total == null) return;
    setState(() => commentCount = total);
  }

  Future<void> toggleLike({bool forceLike = false}) async {
    final snap = await EpisodeEngagement.toggleLike(
      episodeId: slideEpisodeId,
      currentlyLiked: liked,
      likeCount: likeCount,
      forceLike: forceLike,
    );
    if (!mounted) return;
    if (snap == null) {
      showPlayerTip(context, '点赞失败，请稍后重试');
      return;
    }
    setState(() {
      liked = snap.liked;
      likeCount = snap.likeCount;
    });
  }

  Future<void> toggleFavorite() async {
    final was = favorited;
    setState(() => favorited = !was);
    final next = await toggleDramaFavorite(
      dp: context.read<DramaProvider>(),
      dramaId: slideDramaId,
      currentlyFav: was,
    );
    if (!mounted) return;
    if (next == null) {
      setState(() => favorited = was);
      showPlayerTip(context, '追剧操作失败');
      return;
    }
    setState(() => favorited = next);
    showPlayerTip(context, next ? '已加入追剧' : '已取消追剧', duration: const Duration(milliseconds: 1200));
  }

  Future<void> presentUnlock({required Future<void> Function() onUnlocked}) async {
    final ok = await presentEpisodeUnlockSheet(
      context,
      episodeId: slideEpisodeId,
      unlockPrice: slideUnlockPrice,
      bundlePrice: slideBundlePrice,
      dramaId: slideDramaId,
      refreshWalletWith: context.read<DramaProvider>(),
    );
    if (ok && mounted) await onUnlocked();
  }

  Future<void> pauseForOverlay() async {
    await pausePlayerForOverlay(
      player: player,
      markPaused: () {
        if (!mounted) return;
        setState(() {
          paused = true;
          showPauseHint = false;
        });
      },
      syncWake: syncWake,
    );
  }

  Future<void> resumeIfActive({bool skip = false}) async {
    if (!mounted) return;
    await resumePlayerIfActive(
      player: player,
      active: slideActive,
      locked: locked,
      skip: skip,
      markPlaying: () {
        if (mounted) setState(() => paused = false);
      },
      syncWake: syncWake,
    );
  }

  void togglePause() {
    final result = applyPauseToggle(
      player,
      locked: locked,
      loading: loading,
      speedUp: speedUp,
    );
    if (result == PauseToggleResult.skipped) return;
    setState(() {
      paused = result == PauseToggleResult.paused;
      showPauseHint = true;
    });
    unawaited(syncWake());
    if (result == PauseToggleResult.resumed) {
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !paused) setState(() => showPauseHint = false);
      });
    }
  }

  void onSingleTap() {
    tapTimer?.cancel();
    tapTimer = Timer(const Duration(milliseconds: 220), togglePause);
  }

  void onDoubleTap(TapDownDetails d) {
    tapTimer?.cancel();
    burst.fire(
      local: d.localPosition,
      locked: locked,
      loading: loading,
      onUpdate: () {
        if (mounted) setState(() {});
      },
      onLike: () => toggleLike(forceLike: true),
    );
  }

  void onLongPressStart() {
    if (!beginSpeedBoost(player, locked: locked, loading: loading)) return;
    setState(() {
      speedUp = true;
      paused = false;
      showPauseHint = false;
    });
  }

  void onLongPressEnd() {
    endSpeedBoost(player, baseSpeed);
    if (mounted) setState(() => speedUp = false);
  }

  Future<void> toggleMute() async {
    final next = await toggleMuteVolume(player, muted);
    if (next == null || !mounted) return;
    setState(() => muted = next);
  }

  Future<void> pickSpeed() async {
    final picked = await pickPlaybackSpeed(
      context,
      player: player,
      current: baseSpeed,
    );
    if (picked == null || !mounted) return;
    setState(() => baseSpeed = picked);
  }

  Future<void> maybeResumePosition(PlayHandle c, DramaProvider dp, {bool tip = false}) async {
    final sec = await resumeEpisodeIfNeeded(
      player: c,
      dp: dp,
      episodeId: slideEpisodeId,
      isMounted: () => mounted,
    );
    if (tip && sec != null && mounted) {
      showPlayerTip(context, '已从 ${PlayerProgressStore.formatClock(sec)} 续播');
    }
  }

  void disposePlaybackBase({required void Function() disposePlayer}) {
    unbindSystemPip();
    stopProgressTimer();
    burst.dispose();
    tapTimer?.cancel();
    player?.removeListener(onVideoTick);
    disposePlayer();
  }
}
