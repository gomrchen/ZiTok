import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../models/drama_models.dart';
import '../../providers/drama_provider.dart';
import '../../providers/settings_provider.dart';
import '../../app.dart';
import '../../services/comment_service.dart';
import '../../widgets/cover_video.dart';
import 'unlock_sheet.dart';
import 'episode_comments_sheet.dart';
import 'episode_label.dart';
import 'episode_picker_sheet.dart';
import 'episode_play_page.dart';
import 'player_extras.dart';
import 'player_overlay.dart';

/// 首页竖屏连播（对齐红果）：上下滑、双击赞、长按倍速、追剧、评论、选集、播完自动下一集
class DramaPlayerPage extends StatefulWidget {
  const DramaPlayerPage({super.key});

  @override
  State<DramaPlayerPage> createState() => _DramaPlayerPageState();
}

class _DramaPlayerPageState extends State<DramaPlayerPage> {
  final PageController _pageController = PageController();
  final Map<int, Future<void> Function()> _moreHandlers = {};
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
    super.dispose();
  }

  void _goNext() {
    final dp = context.read<DramaProvider>();
    if (_index >= dp.feed.length - 1) return;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
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

    final top = MediaQuery.viewPaddingOf(context).top;
    final bal = dp.wallet?.balance;
    final showMore = context.watch<SettingsProvider>().playerMoreButton;

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
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
                itemIndex: i,
                active: i == _index,
                favorited: dp.favorites.any((d) => d.id == item.drama.id),
                nextLabel: next == null
                    ? null
                    : '《${next.drama.title}》第${next.episode.episodeNo}集',
                onEnded: _goNext,
                onRegisterMore: (index, handler) {
                  if (handler == null) {
                    _moreHandlers.remove(index);
                  } else {
                    _moreHandlers[index] = handler;
                  }
                },
              );
            },
          ),
          Positioned(
            top: top + 8,
            right: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showMore) ...[
                  PlayerMoreButton(
                    onTap: () => _moreHandlers[_index]?.call(),
                  ),
                  const SizedBox(width: 8),
                ],
                PlayerCoinChip(
                  balance: bal ?? 0,
                  onTap: () => context.push('/wallet'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EpisodeSlide extends StatefulWidget {
  final FeedItem item;
  final int itemIndex;
  final bool active;
  final bool favorited;
  final String? nextLabel;
  final VoidCallback onEnded;
  final void Function(int index, Future<void> Function()? handler) onRegisterMore;

  const _EpisodeSlide({
    super.key,
    required this.item,
    required this.itemIndex,
    required this.active,
    required this.favorited,
    required this.nextLabel,
    required this.onEnded,
    required this.onRegisterMore,
  });

  @override
  State<_EpisodeSlide> createState() => _EpisodeSlideState();
}

class _EpisodeSlideState extends State<_EpisodeSlide> {
  VideoPlayerController? _controller;
  bool _locked = false;
  bool _loading = true;
  bool _paused = false;
  bool _showPauseHint = false;
  bool _liked = false;
  bool _favorited = false;
  bool _speedUp = false;
  bool _endedHandled = false;
  bool _awaitingNext = false;
  bool _muted = false;
  double _baseSpeed = 1.0;
  int _likeCount = 0;
  int _commentCount = 0;
  String? _error;
  Offset? _burstPos;
  Timer? _progressTimer;
  Timer? _burstTimer;
  Timer? _tapTimer;

  @override
  void initState() {
    super.initState();
    _favorited = widget.favorited;
    widget.onRegisterMore(widget.itemIndex, _openMore);
    _prepare();
  }

  @override
  void didUpdateWidget(covariant _EpisodeSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.itemIndex != oldWidget.itemIndex) {
      oldWidget.onRegisterMore(oldWidget.itemIndex, null);
      widget.onRegisterMore(widget.itemIndex, _openMore);
    }
    if (widget.favorited != oldWidget.favorited) {
      _favorited = widget.favorited;
    }
    if (widget.active && !oldWidget.active) {
      _endedHandled = false;
      _awaitingNext = false;
      if (!_paused) _controller?.play();
      _startProgressTimer();
    } else if (!widget.active && oldWidget.active) {
      _controller?.pause();
      _stopProgressTimer();
      if (_speedUp) {
        _controller?.setPlaybackSpeed(_baseSpeed);
        _speedUp = false;
      }
      _awaitingNext = false;
    }
  }

  Future<void> _prepare() async {
    setState(() {
      _loading = true;
      _error = null;
      _endedHandled = false;
    });
    final dp = context.read<DramaProvider>();
    try {
      final info = await dp.loadPlayInfo(widget.item.episode.id);
      if (!mounted) return;
      if (info == null) {
        setState(() {
          _error = '加载失败';
          _loading = false;
        });
        return;
      }
      _locked = info.locked || !info.canPlay;
      if (_locked) {
        setState(() => _loading = false);
        if (widget.active) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _showUnlock());
        }
        return;
      }
      final url = info.videoUrl.isNotEmpty ? info.videoUrl : widget.item.episode.videoUrl;
      final c = VideoPlayerController.networkUrl(Uri.parse(url));
      await c.initialize();
      // 红果：播完切下一集，不循环当前集
      c.setLooping(false);
      c.addListener(_onVideoTick);
      if (!mounted) {
        await c.dispose();
        return;
      }
      _controller = c;
      if (widget.active) await c.play();
      setState(() {
        _loading = false;
        _likeCount = widget.item.episode.likeCount;
      });
      await Future.wait([_syncLikeStatus(), _syncCommentCount()]);
      if (widget.active) _startProgressTimer();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  void _onVideoTick() {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _endedHandled || !widget.active) return;
    final dur = c.value.duration;
    final pos = c.value.position;
    if (dur.inMilliseconds <= 0) return;
    // 播到片尾：可选倒计时，默认直接切下一集
    if (pos >= dur - const Duration(milliseconds: 400)) {
      _endedHandled = true;
      _reportProgressNow();
      final useCountdown = context.read<SettingsProvider>().autoNextCountdown;
      if (useCountdown && widget.nextLabel != null) {
        if (mounted) setState(() => _awaitingNext = true);
      } else {
        widget.onEnded();
      }
    }
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) => _reportProgressNow());
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  void _reportProgressNow() {
    final c = _controller;
    final sec = c?.value.isInitialized == true ? c!.value.position.inSeconds : 0;
    context.read<DramaProvider>().reportProgress(widget.item, positionSec: sec);
  }

  Future<void> _syncLikeStatus() async {
    try {
      final resp = await CommentService(AppBootstrap.apiClient.dio)
          .episodeLikeStatus(episodeId: widget.item.episode.id);
      final raw = resp.data;
      if (!mounted || raw is! Map || '${raw['code']}' != '10000') return;
      final data = raw['data'];
      if (data is! Map) return;
      setState(() {
        _liked = data['liked'] == true;
        final c = data['like_count'];
        if (c is num) _likeCount = c.toInt();
      });
    } catch (_) {}
  }

  Future<void> _syncCommentCount() async {
    try {
      final resp = await CommentService(AppBootstrap.apiClient.dio)
          .episodeCommentList(episodeId: widget.item.episode.id, page: 1, size: 1);
      final raw = resp.data;
      if (!mounted || raw is! Map || '${raw['code']}' != '10000') return;
      final data = raw['data'];
      if (data is! Map) return;
      final t = data['total'];
      if (t is num) setState(() => _commentCount = t.toInt());
    } catch (_) {}
  }

  Future<void> _toggleLike({bool forceLike = false}) async {
    if (forceLike && _liked) return;
    try {
      final resp = await CommentService(AppBootstrap.apiClient.dio)
          .likeEpisode(episodeId: widget.item.episode.id);
      if (!mounted) return;
      final raw = resp.data;
      if (raw is Map && '${raw['code']}' == '10000' && raw['data'] is Map) {
        final data = Map<String, dynamic>.from(raw['data'] as Map);
        var liked = data['liked'] == true;
        // 双击只加点赞：若服务端变成取消，再点一次打回赞
        if (forceLike && !liked) {
          final again = await CommentService(AppBootstrap.apiClient.dio)
              .likeEpisode(episodeId: widget.item.episode.id);
          final raw2 = again.data;
          if (raw2 is Map && raw2['data'] is Map) {
            final d2 = Map<String, dynamic>.from(raw2['data'] as Map);
            liked = d2['liked'] == true;
            setState(() {
              _liked = liked;
              final c = d2['like_count'];
              if (c is num) _likeCount = c.toInt();
            });
            return;
          }
        }
        setState(() {
          _liked = liked;
          final c = data['like_count'];
          if (c is num) _likeCount = c.toInt();
        });
        return;
      }
      setState(() {
        _liked = !_liked;
        _likeCount = (_likeCount + (_liked ? 1 : -1)).clamp(0, 1 << 30);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('点赞失败，请稍后重试'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _toggleFavorite() async {
    final dp = context.read<DramaProvider>();
    final was = _favorited;
    setState(() => _favorited = !was);
    try {
      await dp.toggleFavorite(widget.item.drama.id, currentlyFav: was);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_favorited ? '已加入追剧' : '已取消追剧'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1200),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _favorited = was);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('追剧操作失败'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _showUnlock() async {
    final item = widget.item;
    final ok = await showUnlockSheet(
      context,
      episodeId: item.episode.id,
      unlockPrice: item.episode.unlockPrice,
      bundlePrice: item.drama.bundlePrice,
      dramaId: item.drama.id,
    );
    if (ok == true && mounted) await _prepare();
  }

  void _togglePause() {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _locked || _loading || _speedUp) return;
    if (c.value.isPlaying) {
      c.pause();
      setState(() {
        _paused = true;
        _showPauseHint = true;
      });
    } else {
      c.play();
      setState(() {
        _paused = false;
        _showPauseHint = true;
      });
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_paused) setState(() => _showPauseHint = false);
      });
    }
  }

  void _onSingleTap() {
    _tapTimer?.cancel();
    // 等待是否构成双击，避免暂停与点赞抢手势
    _tapTimer = Timer(const Duration(milliseconds: 220), _togglePause);
  }

  void _onDoubleTap(TapDownDetails d) {
    _tapTimer?.cancel();
    if (_locked || _loading) return;
    setState(() => _burstPos = d.localPosition);
    _burstTimer?.cancel();
    _burstTimer = Timer(const Duration(milliseconds: 750), () {
      if (mounted) setState(() => _burstPos = null);
    });
    _toggleLike(forceLike: true);
  }

  void _onLongPressStart() {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _locked || _loading) return;
    c.setPlaybackSpeed(2.0);
    if (!c.value.isPlaying) c.play();
    setState(() {
      _speedUp = true;
      _paused = false;
      _showPauseHint = false;
    });
  }

  void _onLongPressEnd() {
    _controller?.setPlaybackSpeed(_baseSpeed);
    if (mounted) setState(() => _speedUp = false);
  }

  Future<void> _toggleMute() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final next = !_muted;
    await c.setVolume(next ? 0 : 1);
    if (mounted) setState(() => _muted = next);
  }

  Future<void> _pickSpeed() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final picked = await showPlayerSpeedSheet(context, current: _baseSpeed);
    if (picked == null || !mounted) return;
    await c.setPlaybackSpeed(picked);
    setState(() => _baseSpeed = picked);
  }

  Future<void> _openMore() async {
    final item = widget.item;
    await _controller?.pause();
    if (mounted) {
      setState(() {
        _paused = true;
        _showPauseHint = false;
      });
    }
    if (!mounted) return;
    final action = await showPlayerMoreSheet(
      context,
      muted: _muted,
      speed: _baseSpeed,
    );
    if (!mounted) return;
    switch (action) {
      case PlayerMoreAction.speed:
        await _pickSpeed();
      case PlayerMoreAction.mute:
        await _toggleMute();
      case PlayerMoreAction.intro:
        await showPlayerDramaIntroSheet(context, drama: item.drama);
      case PlayerMoreAction.share:
        await shareDramaEpisode(context, drama: item.drama, episode: item.episode);
      case null:
        break;
    }
    if (widget.active && mounted && !_locked) {
      await _controller?.play();
      if (mounted) setState(() => _paused = false);
    }
  }

  @override
  void dispose() {
    widget.onRegisterMore(widget.itemIndex, null);
    _stopProgressTimer();
    _burstTimer?.cancel();
    _tapTimer?.cancel();
    _controller?.removeListener(_onVideoTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final inset = playerBottomInset(context, withHomeBar: true);
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: _controller != null && _controller!.value.isInitialized
              ? ExcludeSemantics(child: CoverVideo(controller: _controller!))
              : const ColoredBox(color: Colors.black),
        ),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onSingleTap,
            onDoubleTapDown: _onDoubleTap,
            onLongPressStart: (_) => _onLongPressStart(),
            onLongPressEnd: (_) => _onLongPressEnd(),
            onLongPressCancel: _onLongPressEnd,
            child: const SizedBox.expand(),
          ),
        ),
        PlayerEdgeGestureLayer(
          controller: _controller,
          enabled: !_locked && !_loading && !_awaitingNext,
        ),
        if (_burstPos != null) PlayerLikeBurst(localPos: _burstPos!),
        if (_loading) const Center(child: CircularProgressIndicator(color: Colors.white)),
        if (_error != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('播放失败', style: TextStyle(color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _prepare, child: const Text('重试')),
                ],
              ),
            ),
          ),
        if (_locked)
          ColoredBox(
            color: Colors.black54,
            child: Center(
              child: FilledButton(onPressed: _showUnlock, child: const Text('解锁本集')),
            ),
          ),
        const Positioned(left: 0, right: 0, bottom: 0, height: 260, child: PlayerBottomScrim()),
        if (_showPauseHint && !_locked && !_loading && !_speedUp) PlayerPauseHint(paused: _paused),
        if (_speedUp)
          const Positioned(
            top: 120,
            left: 0,
            right: 0,
            child: PlayerSpeedBadge(),
          ),
        Positioned(
          right: 6,
          bottom: inset + 72,
          child: Column(
            children: [
              PlayerSideAction(
                icon: _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                label: _likeCount > 0 ? '$_likeCount' : '点赞',
                iconColor: _liked ? kPlayerPrimary : Colors.white,
                onTap: () => _toggleLike(),
              ),
              PlayerSideAction(
                icon: Icons.chat_bubble_outline_rounded,
                label: _commentCount > 0 ? '$_commentCount' : '评论',
                onTap: () async {
                  await _controller?.pause();
                  setState(() {
                    _paused = true;
                    _showPauseHint = false;
                  });
                  if (!context.mounted) return;
                  await showEpisodeCommentsSheet(context, episodeId: item.episode.id);
                  await _syncCommentCount();
                  if (widget.active && mounted) {
                    await _controller?.play();
                    setState(() => _paused = false);
                  }
                },
              ),
              PlayerSideAction(
                icon: _favorited ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                label: _favorited ? '已追' : '追剧',
                iconColor: _favorited ? kPlayerAccent : Colors.white,
                onTap: _toggleFavorite,
              ),
              PlayerSideAction(
                icon: Icons.list_alt_rounded,
                label: '选集',
                onTap: () async {
                  await _controller?.pause();
                  setState(() {
                    _paused = true;
                    _showPauseHint = false;
                  });
                  if (!context.mounted) return;
                  final ep = await showEpisodePickerSheet(
                    context,
                    drama: item.drama,
                    currentEpisodeId: item.episode.id,
                  );
                  if (!mounted) return;
                  if (ep != null) {
                    if (ep.id == item.episode.id) {
                      await _controller?.play();
                      if (mounted) setState(() => _paused = false);
                      return;
                    }
                    if (!mounted) return;
                    await Navigator.of(this.context).push(
                      MaterialPageRoute(
                        builder: (_) => EpisodePlayPage(drama: item.drama, episode: ep),
                      ),
                    );
                    if (widget.active && mounted) {
                      await _controller?.play();
                      if (mounted) setState(() => _paused = false);
                    }
                  } else if (widget.active && mounted) {
                    await _controller?.play();
                    if (mounted) setState(() => _paused = false);
                  }
                },
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 88,
          bottom: inset + 8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PlayerBottomMeta(
                title: item.drama.title,
                subtitle: episodeSubtitle(item.episode, category: item.drama.category),
                onTitleTap: () => context.push('/drama/${item.drama.id}'),
              ),
              const SizedBox(height: 8),
              PlayerProgressBar(
                controller: _controller,
                onSeek: (_) => _reportProgressNow(),
              ),
            ],
          ),
        ),
        if (_awaitingNext && widget.nextLabel != null)
          Positioned.fill(
            child: PlayerAutoNextCountdown(
              nextLabel: widget.nextLabel!,
              onConfirm: () {
                setState(() => _awaitingNext = false);
                widget.onEnded();
              },
              onCancel: () {
                setState(() => _awaitingNext = false);
                _controller?.seekTo(Duration.zero);
                _controller?.play();
                _endedHandled = false;
              },
            ),
          ),
      ],
    );
  }
}
