import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../app.dart';
import '../../models/drama_models.dart';
import '../../providers/drama_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/comment_service.dart';
import '../../widgets/cover_video.dart';
import 'episode_comments_sheet.dart';
import 'episode_label.dart';
import 'episode_picker_sheet.dart';
import 'player_episode_chrome.dart';
import 'player_extras.dart';
import 'player_overlay.dart';
import 'unlock_sheet.dart';

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
    super.dispose();
  }

  Future<void> _loadEpisodes() async {
    setState(() {
      _loadingList = true;
      _listError = null;
    });
    try {
      final resp = await context.read<DramaProvider>().dramaService.detail(widget.drama.id);
      final raw = resp.data;
      if (raw is! Map || '${raw['code']}' != '10000') {
        throw Exception('加载分集失败');
      }
      final data = Map<String, dynamic>.from(raw['data'] as Map);
      final eps = (data['episodes'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Episode.fromJson(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => a.episodeNo.compareTo(b.episodeNo));
      if (eps.isEmpty) throw Exception('暂无分集');
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
        _listError = '$e';
        _loadingList = false;
      });
    }
  }

  void _goNext() {
    if (_index >= _episodes.length - 1) return;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openPicker() async {
    if (_episodes.isEmpty) return;
    final cur = _episodes[_index];
    final ep = await showEpisodePickerSheet(
      context,
      drama: widget.drama,
      currentEpisodeId: cur.id,
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
            onGoNext: _goNext,
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
  final VoidCallback onGoNext;

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
    required this.onGoNext,
  });

  @override
  State<_EpisodeSlide> createState() => _EpisodeSlideState();
}

class _EpisodeSlideState extends State<_EpisodeSlide> {
  VideoPlayerController? _controller;
  bool _loading = true;
  bool _locked = false;
  bool _paused = false;
  bool _showPauseHint = false;
  bool _liked = false;
  bool _favorited = false;
  bool _speedUp = false;
  bool _endedHandled = false;
  bool _nearEnd = false;
  bool _awaitingNext = false;
  bool _muted = false;
  bool _chromeHidden = false;
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
      _nearEnd = false;
      _awaitingNext = false;
      if (!_paused && !_locked) _controller?.play();
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

  @override
  void dispose() {
    _stopProgressTimer();
    _burstTimer?.cancel();
    _tapTimer?.cancel();
    _controller?.removeListener(_onVideoTick);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    final dp = context.read<DramaProvider>();
    setState(() {
      _loading = true;
      _error = null;
      _locked = false;
      _paused = false;
      _showPauseHint = false;
      _endedHandled = false;
      _nearEnd = false;
      _awaitingNext = false;
      _speedUp = false;
      _muted = false;
      _baseSpeed = 1.0;
    });
    await _controller?.dispose();
    _controller = null;
    if (!mounted) return;
    try {
      final info = await dp.loadPlayInfo(widget.episode.id);
      if (!mounted) return;
      if (info == null) {
        setState(() {
          _error = '加载失败';
          _loading = false;
        });
        return;
      }
      if (info.locked || !info.canPlay || info.videoUrl.isEmpty) {
        setState(() {
          _locked = true;
          _loading = false;
        });
        if (widget.active) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
        }
        return;
      }
      final url = info.videoUrl.isNotEmpty ? info.videoUrl : widget.episode.videoUrl;
      final c = VideoPlayerController.networkUrl(Uri.parse(url));
      await c.initialize();
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
        _likeCount = widget.episode.likeCount;
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
    if (c == null || !c.value.isInitialized || !widget.active) return;
    final dur = c.value.duration;
    final pos = c.value.position;
    if (dur.inMilliseconds <= 0) return;

    final remain = dur - pos;
    final near = remain <= const Duration(seconds: 8) && widget.nextEpisode != null;
    if (near != _nearEnd && mounted) setState(() => _nearEnd = near);

    if (_endedHandled) return;
    if (pos >= dur - const Duration(milliseconds: 400)) {
      _endedHandled = true;
      _reportProgressNow();
      final useCountdown = context.read<SettingsProvider>().autoNextCountdown;
      if (useCountdown && widget.nextEpisode != null) {
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
    context.read<DramaProvider>().reportProgress(
          FeedItem(drama: widget.drama, episode: widget.episode),
          positionSec: sec,
        );
  }

  Future<void> _syncLikeStatus() async {
    try {
      final resp = await CommentService(AppBootstrap.apiClient.dio)
          .episodeLikeStatus(episodeId: widget.episode.id);
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
          .episodeCommentList(episodeId: widget.episode.id, page: 1, size: 1);
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
          .likeEpisode(episodeId: widget.episode.id);
      if (!mounted) return;
      final raw = resp.data;
      if (raw is Map && '${raw['code']}' == '10000' && raw['data'] is Map) {
        final data = Map<String, dynamic>.from(raw['data'] as Map);
        var liked = data['liked'] == true;
        if (forceLike && !liked) {
          final again = await CommentService(AppBootstrap.apiClient.dio)
              .likeEpisode(episodeId: widget.episode.id);
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
      await dp.toggleFavorite(widget.drama.id, currentlyFav: was);
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

  Future<void> _unlock() async {
    final ok = await showUnlockSheet(
      context,
      episodeId: widget.episode.id,
      unlockPrice: widget.episode.unlockPrice,
      bundlePrice: widget.drama.bundlePrice,
      dramaId: widget.drama.id,
    );
    if (ok == true && mounted) {
      await context.read<DramaProvider>().refreshWallet();
      await _prepare();
    }
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
    if (!mounted || !widget.active || _locked) return;
    await _controller?.play();
    if (mounted) setState(() => _paused = false);
  }

  Future<void> _openTitle() async {
    await _pauseForOverlay();
    if (!mounted) return;
    await context.push('/drama/${widget.drama.id}');
    await _resumeIfActive();
  }

  Future<void> _openEpisodeMeta() async {
    await _pauseForOverlay();
    await widget.onOpenPicker();
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
        await showPlayerDramaIntroSheet(context, drama: widget.drama);
      case PlayerMoreAction.share:
        await shareDramaEpisode(context, drama: widget.drama, episode: widget.episode);
      case null:
        break;
    }
    if (mounted && widget.active && !_locked) {
      await _controller?.play();
      if (mounted) setState(() => _paused = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dockH = playerEpisodeDockHeight(context);
    final next = widget.nextEpisode;
    final likeLabel = formatPlayerCount(_likeCount);
    final showChrome = !_chromeHidden;

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
            onTap: () {
              if (_chromeHidden) {
                setState(() => _chromeHidden = false);
                return;
              }
              _onSingleTap();
            },
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
        if (showChrome)
          const Positioned(top: 0, left: 0, right: 0, height: 140, child: PlayerTopScrim()),
        if (showChrome)
          Positioned(left: 0, right: 0, bottom: dockH, height: 280, child: const PlayerBottomScrim()),
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
              child: FilledButton(onPressed: _unlock, child: const Text('解锁本集')),
            ),
          ),
        if (showChrome && _showPauseHint && !_locked && !_loading && !_speedUp)
          PlayerPauseHint(paused: _paused),
        if (_speedUp)
          const Positioned(
            top: 120,
            left: 0,
            right: 0,
            child: PlayerSpeedBadge(),
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
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                    ),
                    PlayerEpisodeTitleLabel(
                      episodeNo: widget.episode.episodeNo,
                      onTap: _openEpisodeMeta,
                    ),
                    const Spacer(),
                    PlayerSpeedTextButton(
                      speed: _baseSpeed,
                      onTap: () async {
                        await _pauseForOverlay();
                        await _pickSpeed();
                        await _resumeIfActive();
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
          if (_nearEnd && next != null && !_locked && !_loading && !_awaitingNext)
            Positioned(
              right: 16,
              bottom: dockH + 210,
              child: PlayerNextEpisodeHint(
                episodeLabel: '第${next.episodeNo}集',
                onTap: widget.onGoNext,
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
                  icon: _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  label: likeLabel.isNotEmpty ? likeLabel : '点赞',
                  iconColor: _liked ? kPlayerPrimary : Colors.white,
                  onTap: () => _toggleLike(),
                ),
                PlayerSideAction(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: _commentCount > 0 ? '$_commentCount' : '评论',
                  onTap: () async {
                    await _pauseForOverlay();
                    await widget.onOpenComments();
                    await _syncCommentCount();
                    await _resumeIfActive();
                  },
                ),
                PlayerSideAction(
                  icon: _favorited ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  label: _favorited ? '已追' : '追剧',
                  iconColor: _favorited ? kPlayerAccent : Colors.white,
                  onTap: _toggleFavorite,
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
                  onDanmakuTap: () async {
                    await _pauseForOverlay();
                    await widget.onOpenComments();
                    await _resumeIfActive();
                  },
                ),
                const SizedBox(height: 8),
                PlayerProgressBar(
                  controller: _controller,
                  onSeek: (_) => _reportProgressNow(),
                ),
              ],
            ),
          ),
        ],
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: PlayerEpisodeDock(
            totalEpisodes: widget.episodeCount > 0 ? widget.episodeCount : widget.drama.totalEpisodes,
            freeWatch: widget.drama.freeEpisodeCount > 0,
            chromeHidden: _chromeHidden,
            onPickEpisodes: () async {
              await _pauseForOverlay();
              await widget.onOpenPicker();
              await _resumeIfActive();
            },
            onToggleChrome: () => setState(() => _chromeHidden = !_chromeHidden),
          ),
        ),
        if (_awaitingNext && next != null)
          Positioned.fill(
            child: PlayerAutoNextCountdown(
              nextLabel: '第${next.episodeNo}集 · ${widget.drama.title}',
              onConfirm: () {
                setState(() => _awaitingNext = false);
                widget.onGoNext();
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
