import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:dio/dio.dart';

import '../../app.dart';
import '../../models/drama_models.dart';
import '../../providers/drama_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/deep_link_service.dart';
import 'android_system_pip.dart';
import 'drama_detail_loader.dart';
import 'episode_comments_sheet.dart';
import 'episode_label.dart';
import 'episode_picker_sheet.dart';
import 'episode_slide_playback_mixin.dart';
import 'media_url.dart';
import 'player_cast_quality.dart';
import 'player_danmaku.dart';
import 'player_episode_chrome.dart';
import 'player_extras.dart';
import 'player_handle.dart';
import 'player_overlay.dart';
import 'player_pip.dart';
import 'player_poster.dart';
import 'player_runtime.dart';
import 'player_session.dart';
import 'player_subtitle.dart';
import '../../widgets/glass_nav.dart';

/// 剧场/详情进入的全屏播放：上下滑切集、双击赞、长按倍速、追剧、播完自动下一集
class EpisodePlayPage extends StatefulWidget {
  final Drama drama;
  final Episode episode;

  const EpisodePlayPage({super.key, required this.drama, required this.episode});

  @override
  State<EpisodePlayPage> createState() => _EpisodePlayPageState();
}

class _EpisodePlayPageState extends State<EpisodePlayPage> {
  final PageController _pageController = PageController();
  List<Episode> _episodes = [];
  int _index = 0;
  bool _loadingList = true;
  String? _listError;

  @override
  void initState() {
    super.initState();
    PlayerPipController.episodePageBuilder ??= (d, e) => EpisodePlayPage(drama: d, episode: e);
    // 打开其它剧集时关掉冲突小窗；同集由 prepare 认领小窗 handle
    if (PlayerPipController.isOpen && PlayerPipController.ownerId != widget.episode.id) {
      PlayerPipController.close(disposeHandle: true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dp = context.read<DramaProvider>();
      dp.refreshWallet();
      dp.refreshWatching();
    });
    _loadEpisodes();
  }

  @override
  void dispose() {
    _pageController.dispose();
    EpisodeVideoPreload.discardAll();
    // 小窗离页续播时保留常亮
    if (!PlayerPipController.isOpen) {
      PlayerWakelock.clearAll();
    } else {
      PlayerWakelock.sync(holder: 'pip', keepOn: true);
    }
    super.dispose();
  }

  Future<void> _loadEpisodes() async {
    setState(() {
      _loadingList = true;
      _listError = null;
    });
    try {
      final bundle = await loadDramaDetailBundle(
        context.read<DramaProvider>(),
        widget.drama.id,
        requireEpisodes: true,
      );
      final eps = bundle.episodes;
      var idx = eps.indexWhere((e) => e.id == widget.episode.id);
      if (idx < 0) idx = 0;
      if (!mounted) return;
      setState(() {
        _episodes = eps;
        _index = idx;
        _loadingList = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(idx);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _listError = playerFriendlyError(e, fallback: '分集加载失败');
        _loadingList = false;
      });
    }
  }

  void _goNext() {
    if (_index >= _episodes.length - 1) return;
    unawaited(animateToNextPage(_pageController));
  }

  Future<void> _openPicker() async {
    if (_episodes.isEmpty) return;
    final cur = _episodes[_index];
    final ep = await showEpisodePickerSheet(
      context,
      drama: widget.drama,
      currentEpisodeId: cur.id,
      episodes: _episodes,
    );
    if (!mounted || ep == null) return;
    final i = _episodes.indexWhere((e) => e.id == ep.id);
    if (i >= 0) {
      _pageController.animateToPage(
        i,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DramaProvider>();
    final favorited = dp.favorites.any((d) => d.id == widget.drama.id);
    final showMore = context.watch<SettingsProvider>().playerMoreButton;

    if (_loadingList) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    if (_listError != null || _episodes.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_listError ?? '暂无分集', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
              FilledButton(onPressed: _loadEpisodes, child: const Text('重试')),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('返回', style: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        controller: _pageController,
        itemCount: _episodes.length,
        onPageChanged: (i) {
          setState(() => _index = i);
          final ep = _episodes[i];
          context.read<DramaProvider>().reportProgress(
                FeedItem(drama: widget.drama, episode: ep),
              );
        },
        itemBuilder: (_, i) {
          final next = i + 1 < _episodes.length ? _episodes[i + 1] : null;
          return _EpisodeSlide(
            key: ValueKey('play-ep-${_episodes[i].id}'),
            drama: widget.drama,
            episode: _episodes[i],
            nextEpisode: next,
            active: i == _index,
            favorited: favorited,
            episodeCount: _episodes.length,
            showMore: showMore,
            onEnded: _goNext,
            onOpenComments: () => showEpisodeCommentsSheet(context, episodeId: _episodes[i].id),
            onOpenPicker: _openPicker,
          );
        },
      ),
    );
  }
}

class _EpisodeSlide extends StatefulWidget {
  final Drama drama;
  final Episode episode;
  final Episode? nextEpisode;
  final bool active;
  final bool favorited;
  final int episodeCount;
  final bool showMore;
  final VoidCallback onEnded;
  final Future<void> Function() onOpenComments;
  final Future<void> Function() onOpenPicker;

  const _EpisodeSlide({
    super.key,
    required this.drama,
    required this.episode,
    required this.nextEpisode,
    required this.active,
    required this.favorited,
    required this.episodeCount,
    required this.showMore,
    required this.onEnded,
    required this.onOpenComments,
    required this.onOpenPicker,
  });

  @override
  State<_EpisodeSlide> createState() => _EpisodeSlideState();
}

class _EpisodeSlideState extends State<_EpisodeSlide> with EpisodeSlidePlaybackMixin {
  bool _nearEnd = false;
  bool _chromeHidden = false;
  bool _subtitleOn = false;
  final GlobalKey _videoBoundaryKey = GlobalKey();
  String _playUrl = '';
  String _qualityLabel = '自动';
  List<VideoQualityOption> _qualities = const [];
  List<SubtitleCue> _cues = const [];
  String _subtitleUrl = '';

  @override
  int get slideEpisodeId => widget.episode.id;
  @override
  int get slideDramaId => widget.drama.id;
  @override
  int get slideEpisodeNo => widget.episode.episodeNo;
  @override
  int get slideUnlockPrice => widget.episode.unlockPrice;
  @override
  int get slideBundlePrice => widget.drama.bundlePrice;
  @override
  int get slideInitialLikeCount => widget.episode.likeCount;
  @override
  bool get slideActive => widget.active;
  @override
  bool get slideFavorited => widget.favorited;
  @override
  bool get slideHasNext => widget.nextEpisode != null;
  @override
  FeedItem get slideProgressItem => FeedItem(drama: widget.drama, episode: widget.episode);
  @override
  int? get slideWarmNextEpisodeId => widget.nextEpisode?.id;
  @override
  String get slideWarmNextFallbackUrl => widget.nextEpisode?.videoUrl ?? '';
  @override
  VoidCallback get slideOnEnded => widget.onEnded;
  @override
  bool get slideRespectLockOnActivate => true;
  @override
  VoidCallback? get slideOnSystemPipChanged => _onSystemPipChanged;
  @override
  String get slideVideoFallbackUrl => widget.episode.videoUrl;
  @override
  EpisodeOpenMode get slideOpenMode => EpisodeOpenMode.full;
  @override
  bool get slideShowResumeTip => true;

  @override
  void slideOnBecameActiveExtraReset() {
    _nearEnd = false;
  }

  @override
  void slideOnNearEndChanged(bool near) {
    if (near != _nearEnd) setState(() => _nearEnd = near);
  }

  @override
  void slideResetPrepareUiExtra() {
    locked = false;
    paused = false;
    showPauseHint = false;
    _nearEnd = false;
    awaitingNext = false;
    speedUp = false;
    muted = false;
    baseSpeed = 1.0;
    _cues = const [];
    _subtitleUrl = '';
    _subtitleOn = false;
  }

  @override
  Future<void> slideOnPlayInfoReady(PlayInfo info, String url) async {
    _playUrl = url;
    _qualities = buildQualityOptions(primaryUrl: url, rawQualities: info.qualities);
    _qualityLabel = _qualities.isNotEmpty ? _qualities.first.label : '自动';
    _subtitleUrl = info.subtitleUrl.trim();
    await _loadSubtitles(_subtitleUrl);
  }

  @override
  Future<PlayHandle?> slideClaimExistingPlayer() async {
    var c = PlayerPipController.claimPendingRestore(episodeId: widget.episode.id);
    if (c == null && PlayerPipController.owns(widget.episode.id)) {
      c = PlayerPipController.takeHandleForRestore();
      PlayerPipController.close(disposeHandle: false);
    }
    return c;
  }

  @override
  bool slideSkipResumeAfterOpen(PlayHandle c) =>
      PlayerPipController.owns(widget.episode.id) || c.position.inSeconds > 2;

  @override
  void initState() {
    super.initState();
    slideInitPlayback();
    _prepare();
  }

  @override
  void didUpdateWidget(covariant _EpisodeSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    slideHandleActiveChanged(
      wasActive: oldWidget.active,
      nowActive: widget.active,
      favoritedChanged: widget.favorited != oldWidget.favorited,
      newFavorited: widget.favorited,
    );
  }

  void _onSystemPipChanged() {
    if (!mounted) return;
    if (AndroidSystemPip.inPip.value) {
      setState(() {
        _chromeHidden = true;
        showPauseHint = false;
      });
    } else {
      setState(() => _chromeHidden = false);
    }
  }

  Future<void> _prepare() => prepareEpisodeSlide(onNeedUnlock: _unlock);

  Future<void> _loadSubtitles(String subtitleField) async {
    final field = subtitleField.trim();
    try {
      final httpUrl = sanitizeHttpMediaUrl(field);
      if (httpUrl != null) {
        final resp = await AppBootstrap.apiClient.dio.get<String>(
          httpUrl,
          options: Options(responseType: ResponseType.plain),
        );
        final body = resp.data ?? '';
        if (!mounted) return;
        setState(() => _cues = parseSubtitleTrack(body));
        return;
      }
      // 仅接受内联 VTT/SRT 时间轴正文，拒绝其它自由文本冒充字幕
      if (field.contains('-->') && field.length < 65536) {
        if (!mounted) return;
        setState(() => _cues = parseSubtitleTrack(field));
        return;
      }
    } catch (_) {}
    if (!mounted) return;
    // 无外挂字幕轨时保持空，勿用剧情简介冒充
    setState(() => _cues = const []);
  }

  Future<void> _switchQuality(VideoQualityOption q) async {
    // 引擎内轨：不换源，只切 media_kit VideoTrack
    if (q.isEngineTrack) {
      final ok = await player?.selectEngineTrack(q) ?? false;
      if (!mounted) return;
      if (ok) {
        setState(() => _qualityLabel = q.label);
      } else {
        showPlayerTip(context, '切换清晰度轨失败', duration: const Duration(milliseconds: 1200));
      }
      return;
    }
    if (q.url.isEmpty || q.url == _playUrl) {
      setState(() => _qualityLabel = q.label);
      return;
    }
    final pos = player?.position ?? Duration.zero;
    setState(() {
      loading = true;
      _qualityLabel = q.label;
      _playUrl = q.url;
    });
    try {
      final old = player;
      old?.removeListener(onVideoTick);
      final c = await openPlayHandle(q.url, preferMediaKit: true);
      await applyPlayHandlePrefs(c, muted: muted, speed: baseSpeed);
      await c.seekTo(pos);
      c.addListener(onVideoTick);
      if (!mounted) {
        await c.dispose();
        return;
      }
      player = c;
      await old?.dispose();
      if (widget.active && !paused) await c.play();
      setState(() => loading = false);
      await syncWake();
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = playerFriendlyError(e, fallback: '切换清晰度失败');
        });
      }
    }
  }

  List<VideoQualityOption> _mergedQualityOptions() {
    final base = _qualities.isEmpty
        ? buildQualityOptions(primaryUrl: _playUrl)
        : List<VideoQualityOption>.from(_qualities);
    final tracks = player?.engineTrackOptions() ?? const [];
    if (tracks.isEmpty) return base;
    // 服务端多 URL 优先；引擎轨附在后面（去重 label）
    final labels = base.map((e) => e.label).toSet();
    for (final t in tracks) {
      if (labels.add(t.label)) base.add(t);
    }
    return base;
  }

  Future<void> _openPip() async {
    final c = player;
    if (c == null || !c.isInitialized) return;
    await c.play();
    if (!mounted) return;

    // Android：优先系统画中画；失败再走应用内小窗
    if (AndroidSystemPip.isSupported) {
      final ok = await tryEnterSystemPip(context);
      if (!mounted) return;
      if (ok) {
        setState(() {
          paused = false;
          showPauseHint = false;
          _chromeHidden = true;
        });
        await syncWake();
        return;
      }
    }

    // 应用内小窗：接管后离页续播
    player?.removeListener(onVideoTick);
    PlayerPipController.open(
      context,
      handle: c,
      drama: widget.drama,
      episode: widget.episode,
      ownerId: widget.episode.id,
      popCurrentRoute: true,
      onClosed: () {
        PlayerWakelock.sync(holder: 'pip', keepOn: false);
      },
    );
    player = null;
    setState(() {
      paused = false;
      showPauseHint = false;
      _chromeHidden = true;
    });
    await PlayerWakelock.sync(holder: 'pip', keepOn: true);
  }

  Future<void> _unlock() => presentUnlock(onUnlocked: _prepare);

  Future<void> _openTitle() async {
    await pauseForOverlay();
    if (!mounted) return;
    await context.push('/drama/${widget.drama.id}');
    await resumeIfActive();
  }

  Future<void> _openEpisodeMeta() async {
    await pauseForOverlay();
    await widget.onOpenPicker();
    await resumeIfActive();
  }

  Future<void> _openMore() async {
    await pauseForOverlay();
    if (!mounted) return;
    final action = await showPlayerMoreSheet(
      context,
      muted: muted,
      speed: baseSpeed,
      subtitleOn: _subtitleOn,
      qualityLabel: _qualityLabel,
    );
    if (!mounted) return;
    await dispatchPlayerMoreAction(
      context,
      action: action,
      drama: widget.drama,
      episode: widget.episode,
      onSpeed: pickSpeed,
      onMute: toggleMute,
      onPip: _openPip,
      onQuality: () async {
        final q = await showQualitySheet(
          context,
          options: _mergedQualityOptions(),
          currentUrl: _playUrl,
          currentTrackId: player?.currentVideoTrackId,
        );
        if (q != null) await _switchQuality(q);
      },
      onCast: () => showCastSheet(
        context,
        playUrl: _playUrl,
        deepLink: DeepLinkService.buildDramaEpisodeLink(
          dramaId: widget.drama.id,
          episodeId: widget.episode.id,
        ),
      ),
      onSubtitle: () async {
        final next = !_subtitleOn;
        final engine = player?.supportsEngineSubtitle == true;
        final externalSub = sanitizeHttpMediaUrl(_subtitleUrl);
        final canEngine = engine &&
            ((player?.hasEngineSubtitle ?? false) || externalSub != null);
        final canOverlay = _cues.isNotEmpty;
        if (next && !canEngine && !canOverlay) {
          showPlayerTip(context, '本集暂无字幕');
        } else {
          if (engine) {
            await player?.setEngineSubtitle(
              on: next && canEngine,
              externalUrl: externalSub,
            );
          }
          setState(() => _subtitleOn = next && (canEngine || canOverlay));
        }
      },
      onPoster: () => captureAndSharePoster(
        context,
        boundaryKey: _videoBoundaryKey,
        title: widget.drama.title,
        episodeLabel: '第${widget.episode.episodeNo}集',
        deepLink: DeepLinkService.buildDramaEpisodeLink(
          dramaId: widget.drama.id,
          episodeId: widget.episode.id,
        ),
        ready: player?.isInitialized == true && !loading,
      ),
    );
    if (!mounted) return;
    await resumeIfActive(
      skip: PlayerPipController.isOpen || action == PlayerMoreAction.pip,
    );
  }

  @override
  void dispose() {
    disposePlaybackBase(
      disposePlayer: () {
        if (PlayerPipController.owns(widget.episode.id)) {
          player = null;
        } else {
          PlayerPipController.closeIfOwner(widget.episode.id);
          player?.dispose();
          player = null;
          PlayerWakelock.sync(holder: widget.episode.id, keepOn: false);
        }
      },
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dockH = playerEpisodeDockHeight(context);
    final next = widget.nextEpisode;
    final likeLabel = formatPlayerCount(likeCount);
    final sysPip = AndroidSystemPip.isSupported && AndroidSystemPip.inPip.value;
    final showChrome = !_chromeHidden && !sysPip;
    final pipOn = PlayerPipController.isOpen;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            key: _videoBoundaryKey,
            // 小窗打开时主区不渲染同一路画面，避免「一大一小两路同画」
            child: pipOn
                ? const ColoredBox(
                    color: Color(0xFF0A0C12),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.picture_in_picture_alt_outlined, color: Colors.white54, size: 40),
                          SizedBox(height: 12),
                          Text(
                            '小窗播放中',
                            style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 6),
                          Text(
                            '点小窗还原，或点下方控件关闭',
                            style: TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  )
                : (player != null && player!.isInitialized
                    ? ExcludeSemantics(child: player!.buildCover())
                    : const ColoredBox(color: Colors.black)),
          ),
        ),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (pipOn) {
                PlayerPipController.close();
                setState(() => _chromeHidden = false);
                return;
              }
              if (_chromeHidden) {
                setState(() => _chromeHidden = false);
                return;
              }
              onSingleTap();
            },
            onDoubleTapDown: onDoubleTap,
            onLongPressStart: (_) => onLongPressStart(),
            onLongPressEnd: (_) => onLongPressEnd(),
            onLongPressCancel: onLongPressEnd,
            child: const SizedBox.expand(),
          ),
        ),
        PlayerDanmakuLayer(
          key: ValueKey('dm-${widget.episode.id}'),
          items: danmakuItems,
          handle: player,
          enabled: danmakuOn && !locked && widget.active,
          paused: paused || awaitingNext,
        ),
        PlayerSubtitleLayer(
          handle: player,
          cues: _cues,
          // media_kit 引擎字幕烧屏时不叠 overlay，避免双字幕
          enabled: _subtitleOn && !locked && _cues.isNotEmpty && !(player?.supportsEngineSubtitle == true),
        ),
        PlayerEdgeGestureLayer(
          handle: player,
          enabled: !locked && !loading && !awaitingNext,
        ),
        if (showChrome)
          const Positioned(top: 0, left: 0, right: 0, height: 140, child: PlayerTopScrim()),
        if (showChrome)
          Positioned(left: 0, right: 0, bottom: dockH, height: 280, child: const PlayerBottomScrim()),
        PlayerPlaybackStatusStack(
          loading: loading,
          locked: locked,
          speedUp: speedUp,
          showPauseHint: showChrome && showPauseHint,
          paused: paused,
          player: player,
          error: error,
          onRetry: _prepare,
          onUnlock: _unlock,
          burstPos: burst.position,
          showBuffering: !pipOn,
        ),
        if (showChrome) ...[
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 2, 8, 0),
                child: Row(
                  children: [
                    GlassNavButton(
                      tooltip: '返回',
                      icon: Icons.arrow_back_ios_new_rounded,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 8),
                    PlayerEpisodeTitleLabel(
                      episodeNo: widget.episode.episodeNo,
                      onTap: _openEpisodeMeta,
                    ),
                    const Spacer(),
                    PlayerSpeedTextButton(
                      speed: baseSpeed,
                      onTap: () async {
                        await pauseForOverlay();
                        await pickSpeed();
                        await resumeIfActive();
                      },
                    ),
                    if (widget.showMore)
                      IconButton(
                        onPressed: _openMore,
                        icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 22),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_nearEnd && next != null && !locked && !loading && !awaitingNext)
            Positioned(
              right: 16,
              bottom: dockH + 210,
              child: PlayerNextEpisodeHint(
                episodeLabel: '第${next.episodeNo}集',
                onTap: widget.onEnded,
              ),
            ),
          Positioned(
            right: 10,
            bottom: dockH + 88,
            width: PlayerSideAction.slotWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                PlayerSideAction(
                  icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  label: likeLabel.isNotEmpty ? likeLabel : '点赞',
                  iconColor: liked ? kPlayerPrimary : Colors.white,
                  onTap: () => toggleLike(),
                ),
                PlayerSideAction(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: commentCount > 0 ? '$commentCount' : '评论',
                  onTap: () async {
                    await pauseForOverlay();
                    await widget.onOpenComments();
                    await syncCommentCount();
                    await resumeIfActive();
                  },
                ),
                PlayerSideAction(
                  icon: favorited ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  label: favorited ? '已追' : '追剧',
                  iconColor: favorited ? kPlayerAccent : Colors.white,
                  onTap: toggleFavorite,
                ),
                PlayerSideAction(
                  icon: Icons.ios_share_rounded,
                  label: '分享',
                  onTap: () => shareDramaEpisode(
                    context,
                    drama: widget.drama,
                    episode: widget.episode,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 10 + PlayerSideAction.slotWidth + 10,
            bottom: dockH + 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PlayerBottomMeta(
                  title: widget.drama.title,
                  episodeNo: widget.episode.episodeNo,
                  synopsis: dramaSynopsis(widget.drama, widget.episode),
                  onTitleTap: _openTitle,
                  onEpisodeTap: _openEpisodeMeta,
                  danmakuOn: danmakuOn,
                  onDanmakuTap: () {
                    final next = !danmakuOn;
                    setState(() => danmakuOn = next);
                    if (next && danmakuItems.isEmpty) {
                      unawaited(loadDanmaku());
                    }
                  },
                ),
                const SizedBox(height: 8),
                PlayerProgressBar(
                  handle: player,
                  onSeek: (_) => reportProgressNow(),
                ),
              ],
            ),
          ),
        ],
        if (!pipOn)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: PlayerEpisodeDock(
              totalEpisodes: widget.episodeCount > 0 ? widget.episodeCount : widget.drama.totalEpisodes,
              freeWatch: widget.drama.freeEpisodeCount > 0,
              chromeHidden: _chromeHidden,
              onPickEpisodes: () async {
                await pauseForOverlay();
                await widget.onOpenPicker();
                await resumeIfActive();
              },
              onToggleChrome: _openPip,
            ),
          ),
        if (awaitingNext && next != null)
          Positioned.fill(
            child: PlayerAutoNextCountdown(
              nextLabel: '第${next.episodeNo}集 · ${widget.drama.title}',
              onConfirm: () {
                setState(() => awaitingNext = false);
                widget.onEnded();
              },
              onCancel: () {
                setState(() => awaitingNext = false);
                player?.seekTo(Duration.zero);
                player?.play();
                endedHandled = false;
              },
            ),
          ),
      ],
    );
  }
}

