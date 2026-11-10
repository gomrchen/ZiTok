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
  final bool active;
  final bool favorited;
  final String? nextLabel;
  final VoidCallback onEnded;

  const _EpisodeSlide({
    super.key,
    required this.item,
    required this.active,
    required this.favorited,
    required this.nextLabel,
    required this.onEnded,
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
    _prepare();
  }

  @override
  void didUpdateWidget(covariant _EpisodeSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
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
        _controller?.setPlaybackSpeed(1.0);
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

  Future<void> _pauseForOverlay() async {
    await _controller?.pause();
    if (!mounted) return;
    setState(() {
      _paused = true;
      _showPauseHint = false;
    });
  }

  Future<void> _resumeIfActive() async {
    if (!mounted || !widget.active) return;
    await _controller?.play();
    if (mounted) setState(() => _paused = false);
  }

  Future<void> _openComments() async {
    await _pauseForOverlay();
    if (!mounted) return;
    await showEpisodeCommentsSheet(context, episodeId: widget.item.episode.id);
    await _syncCommentCount();
    await _resumeIfActive();
  }

  Future<void> _openPicker() async {
    final item = widget.item;
    await _pauseForOverlay();
    if (!mounted) return;
    final ep = await showEpisodePickerSheet(
      context,
      drama: item.drama,
      currentEpisodeId: item.episode.id,
    );
    if (!mounted) return;
    if (ep != null) {
      if (ep.id == item.episode.id) {
        await _resumeIfActive();
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EpisodePlayPage(drama: item.drama, episode: ep),
        ),
      );
      await _resumeIfActive();
    } else {
      await _resumeIfActive();
    }
  }

  Future<void> _openTitle() async {
    await _pauseForOverlay();
    if (!mounted) return;
    await context.push('/drama/${widget.item.drama.id}');
    await _resumeIfActive();
  }

  /// 「观看完整短剧」→ 沉浸剧集播放页（非整页详情）
  Future<void> _openFullDrama() async {
    await _pauseForOverlay();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EpisodePlayPage(
          drama: widget.item.drama,
          episode: widget.item.episode,
        ),
      ),
    );
    await _resumeIfActive();
  }

  Future<void> _openCategory(String tag) async {
    final q = tag.trim();
    if (q.isEmpty) return;
    await _pauseForOverlay();
    if (!mounted) return;
    await context.push('/theater?category=${Uri.encodeComponent(q)}');
    await _resumeIfActive();
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
    _controller?.setPlaybackSpeed(1.0);
    if (mounted) setState(() => _speedUp = false);
  }

  @override
  void dispose() {
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
        const Positioned(left: 0, right: 0, bottom: 0, height: 340, child: PlayerBottomScrim()),
        if (_showPauseHint && !_locked && !_loading && !_speedUp) PlayerPauseHint(paused: _paused),
        if (_speedUp)
          const Positioned(
            top: 120,
            left: 0,
            right: 0,
            child: PlayerSpeedBadge(),
          ),
        Positioned(
          right: 10,
          bottom: inset + 96,
          width: PlayerSideAction.slotWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
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
                onTap: _openComments,
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
                onTap: _openPicker,
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
                onDanmakuTap: _openComments,
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
