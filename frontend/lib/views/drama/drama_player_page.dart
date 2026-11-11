import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/drama_models.dart';
import '../../providers/drama_provider.dart';
import 'episode_comments_sheet.dart';
import 'episode_label.dart';
import 'episode_picker_sheet.dart';
import 'episode_play_page.dart';
import 'episode_slide_playback_mixin.dart';
import 'player_danmaku.dart';
import 'player_episode_chrome.dart';
import 'player_extras.dart';
import 'player_overlay.dart';
import 'player_runtime.dart';
import 'player_session.dart';

/// 首页竖屏连播（对齐红果）：上下滑、双击赞、长按倍速、追剧、评论、选集、播完自动下一集
class DramaPlayerPage extends StatefulWidget {
  const DramaPlayerPage({super.key});

  @override
  State<DramaPlayerPage> createState() => _DramaPlayerPageState();
}

class _DramaPlayerPageState extends State<DramaPlayerPage> {
  final PageController _pageController = PageController();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dp = context.read<DramaProvider>();
      if (dp.feed.isEmpty) dp.refreshFeed();
      dp.refreshWallet();
      dp.refreshWatching();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    EpisodeVideoPreload.discardAll();
    PlayerWakelock.clearAll();
    super.dispose();
  }

  void _goNext() {
    final dp = context.read<DramaProvider>();
    if (_index >= dp.feed.length - 1) return;
    unawaited(animateToNextPage(_pageController));
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DramaProvider>();
    if (dp.loadingFeed && dp.feed.isEmpty) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    if (dp.feed.isEmpty) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(dp.feedError ?? '暂无短剧', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => dp.refreshFeed(), child: const Text('重试')),
            ],
          ),
        ),
      );
    }

    // 封面连播对齐红果：右上不挂更多/金币，沉浸只留画面与侧栏
    return ColoredBox(
      color: Colors.black,
      child: PageView.builder(
        scrollDirection: Axis.vertical,
        controller: _pageController,
        itemCount: dp.feed.length,
        onPageChanged: (i) {
          setState(() => _index = i);
          dp.reportProgress(dp.feed[i]);
          if (i >= dp.feed.length - 2) dp.loadMoreFeed();
        },
        itemBuilder: (context, i) {
          final item = dp.feed[i];
          final next = i + 1 < dp.feed.length ? dp.feed[i + 1] : null;
          return _EpisodeSlide(
            key: ValueKey('feed-ep-${item.episode.id}'),
            item: item,
            nextItem: next,
            active: i == _index,
            favorited: dp.favorites.any((d) => d.id == item.drama.id),
            nextLabel: next == null
                ? null
                : '《${next.drama.title}》第${next.episode.episodeNo}集',
            onEnded: _goNext,
          );
        },
      ),
    );
  }
}

class _EpisodeSlide extends StatefulWidget {
  final FeedItem item;
  final FeedItem? nextItem;
  final bool active;
  final bool favorited;
  final String? nextLabel;
  final VoidCallback onEnded;

  const _EpisodeSlide({
    super.key,
    required this.item,
    required this.nextItem,
    required this.active,
    required this.favorited,
    required this.nextLabel,
    required this.onEnded,
  });

  @override
  State<_EpisodeSlide> createState() => _EpisodeSlideState();
}

class _EpisodeSlideState extends State<_EpisodeSlide> with EpisodeSlidePlaybackMixin {
  @override
  int get slideEpisodeId => widget.item.episode.id;
  @override
  int get slideDramaId => widget.item.drama.id;
  @override
  int get slideEpisodeNo => widget.item.episode.episodeNo;
  @override
  int get slideUnlockPrice => widget.item.episode.unlockPrice;
  @override
  int get slideBundlePrice => widget.item.drama.bundlePrice;
  @override
  int get slideInitialLikeCount => widget.item.episode.likeCount;
  @override
  bool get slideActive => widget.active;
  @override
  bool get slideFavorited => widget.favorited;
  @override
  bool get slideHasNext => widget.nextLabel != null;
  @override
  FeedItem get slideProgressItem => widget.item;
  @override
  int? get slideWarmNextEpisodeId => widget.nextItem?.episode.id;
  @override
  String get slideWarmNextFallbackUrl => widget.nextItem?.episode.videoUrl ?? '';
  @override
  VoidCallback get slideOnEnded => widget.onEnded;
  @override
  String get slideVideoFallbackUrl => widget.item.episode.videoUrl;
  @override
  EpisodeOpenMode get slideOpenMode => EpisodeOpenMode.feed;

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

  Future<void> _openSystemPip() async {
    final c = player;
    if (c == null || !c.isInitialized) return;
    await c.play();
    if (!mounted) return;
    setState(() {
      paused = false;
      showPauseHint = false;
    });
    await syncWake();
    if (!mounted) return;
    await tryEnterSystemPip(
      context,
      unsupportedHint: '请点「观看完整短剧」使用小窗',
    );
  }

  Future<void> _prepare() => prepareEpisodeSlide(onNeedUnlock: _showUnlock);

  Future<void> _showUnlock() => presentUnlock(onUnlocked: _prepare);

  Future<void> _openComments() async {
    await pauseForOverlay();
    if (!mounted) return;
    await showEpisodeCommentsSheet(context, episodeId: widget.item.episode.id);
    await syncCommentCount();
    await resumeIfActive();
  }

  Future<void> _openPicker() async {
    final item = widget.item;
    await pauseForOverlay();
    if (!mounted) return;
    final ep = await showEpisodePickerSheet(
      context,
      drama: item.drama,
      currentEpisodeId: item.episode.id,
    );
    if (!mounted) return;
    if (ep != null) {
      if (ep.id == item.episode.id) {
        await resumeIfActive();
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EpisodePlayPage(drama: item.drama, episode: ep),
        ),
      );
      await resumeIfActive();
    } else {
      await resumeIfActive();
    }
  }

  Future<void> _openTitle() async {
    await pauseForOverlay();
    if (!mounted) return;
    await context.push('/drama/${widget.item.drama.id}');
    await resumeIfActive();
  }

  Future<void> _openFullDrama() async {
    await pauseForOverlay();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EpisodePlayPage(
          drama: widget.item.drama,
          episode: widget.item.episode,
        ),
      ),
    );
    await resumeIfActive();
  }

  Future<void> _openCategory(String tag) async {
    final q = tag.trim();
    if (q.isEmpty) return;
    await pauseForOverlay();
    if (!mounted) return;
    await context.push('/theater?category=${Uri.encodeComponent(q)}');
    await resumeIfActive();
  }

  Future<void> _openMore() async {
    await pauseForOverlay();
    if (!mounted) return;
    final action = await showPlayerMoreSheet(
      context,
      muted: muted,
      speed: baseSpeed,
      compact: true,
    );
    if (!mounted) return;
    switch (action) {
      case PlayerMoreAction.speed:
        await pickSpeed();
      case PlayerMoreAction.mute:
        await toggleMute();
      case PlayerMoreAction.intro:
        await showPlayerDramaIntroSheet(context, drama: widget.item.drama);
      case PlayerMoreAction.share:
        await shareDramaEpisode(
          context,
          drama: widget.item.drama,
          episode: widget.item.episode,
        );
      case PlayerMoreAction.pip:
        await _openSystemPip();
        break;
      case PlayerMoreAction.quality:
      case PlayerMoreAction.cast:
      case PlayerMoreAction.subtitle:
      case PlayerMoreAction.poster:
        showPlayerTip(context, '请点「观看完整短剧」使用该功能');
        break;
      case null:
        break;
    }
    await resumeIfActive();
  }

  @override
  void dispose() {
    disposePlaybackBase(
      disposePlayer: () {
        player?.dispose();
        player = null;
        PlayerWakelock.sync(holder: widget.item.episode.id, keepOn: false);
      },
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final inset = playerBottomInset(context, withHomeBar: true);
    final likeLabel = formatPlayerCount(likeCount);
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: player != null && player!.isInitialized
              ? ExcludeSemantics(child: player!.buildCover())
              : const ColoredBox(color: Colors.black),
        ),
        PlayerGestureSurface(
          onTap: onSingleTap,
          onDoubleTapDown: onDoubleTap,
          onLongPressStart: (_) => onLongPressStart(),
          onLongPressEnd: (_) => onLongPressEnd(),
          onLongPressCancel: onLongPressEnd,
        ),
        PlayerDanmakuLayer(
          key: ValueKey('feed-dm-${widget.item.episode.id}'),
          items: danmakuItems,
          handle: player,
          enabled: danmakuOn && !locked && widget.active,
          paused: paused || awaitingNext,
        ),
        PlayerEdgeGestureLayer(
          handle: player,
          enabled: !locked && !loading && !awaitingNext,
        ),
        PlayerPlaybackStatusStack(
          loading: loading,
          locked: locked,
          speedUp: speedUp,
          showPauseHint: showPauseHint,
          paused: paused,
          player: player,
          error: error,
          onRetry: _prepare,
          onUnlock: _showUnlock,
          burstPos: burst.position,
        ),
        const Positioned(left: 0, right: 0, bottom: 0, height: 340, child: PlayerBottomScrim()),
        Positioned(
          right: 10,
          bottom: inset + 96,
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
                onTap: _openComments,
              ),
              PlayerSideAction(
                icon: favorited ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                label: favorited ? '已追' : '追剧',
                iconColor: favorited ? kPlayerAccent : Colors.white,
                onTap: toggleFavorite,
              ),
              PlayerSideAction(
                icon: Icons.list_alt_rounded,
                label: '选集',
                onTap: _openPicker,
              ),
              PlayerSideAction(
                icon: Icons.ios_share_rounded,
                label: '分享',
                onTap: () => shareDramaEpisode(
                  context,
                  drama: item.drama,
                  episode: item.episode,
                ),
              ),
              PlayerSideAction(
                icon: Icons.more_horiz_rounded,
                label: '更多',
                onTap: _openMore,
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 10 + PlayerSideAction.slotWidth + 10,
          bottom: inset + 8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PlayerBottomMeta(
                title: item.drama.title,
                episodeNo: item.episode.episodeNo,
                synopsis: dramaSynopsis(item.drama, item.episode),
                tags: dramaMetaTags(item.drama),
                totalEpisodes: item.drama.totalEpisodes,
                showNewBadge: dramaShowNewBadge(item.drama),
                onTitleTap: _openTitle,
                onEpisodeTap: _openPicker,
                onWatchFull: _openFullDrama,
                onTagTap: _openCategory,
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
        if (awaitingNext && widget.nextLabel != null)
          Positioned.fill(
            child: PlayerAutoNextCountdown(
              nextLabel: widget.nextLabel!,
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
