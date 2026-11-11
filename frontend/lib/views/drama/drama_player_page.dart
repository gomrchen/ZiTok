import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/drama_models.dart';
import '../../providers/drama_provider.dart';
import '../../providers/settings_provider.dart';
import '../../app.dart';
import '../../services/comment_service.dart';
import 'unlock_sheet.dart';
import 'episode_comments_sheet.dart';
import 'episode_label.dart';
import 'episode_picker_sheet.dart';
import 'episode_play_page.dart';
import 'android_system_pip.dart';
import 'player_danmaku.dart';
import 'player_episode_chrome.dart';
import 'player_extras.dart';
import 'player_handle.dart';
import 'player_overlay.dart';
import 'player_runtime.dart';

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

class _EpisodeSlideState extends State<_EpisodeSlide> {
  PlayHandle? _player;
  bool _locked = false;
  bool _loading = true;
  bool _paused = false;
  bool _showPauseHint = false;
  bool _liked = false;
  bool _favorited = false;
  bool _speedUp = false;
  bool _endedHandled = false;
  bool _awaitingNext = false;
  bool _danmakuOn = false;
  bool _muted = false;
  double _baseSpeed = 1.0;
  int _likeCount = 0;
  int _commentCount = 0;
  String? _error;
  List<DanmakuItem> _danmakuItems = const [];
  Offset? _burstPos;
  Timer? _progressTimer;
  Timer? _burstTimer;
  Timer? _tapTimer;

  bool _systemPipBound = false;

  @override
  void initState() {
    super.initState();
    _favorited = widget.favorited;
    if (widget.active) _bindSystemPip();
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
      if (!_paused) _player?.play();
      _startProgressTimer();
      _syncWake();
      unawaited(_warmNext());
      _bindSystemPip();
    } else if (!widget.active && oldWidget.active) {
      _unbindSystemPip();
      _player?.pause();
      _stopProgressTimer();
      if (_speedUp) {
        _player?.setPlaybackSpeed(_baseSpeed);
        _speedUp = false;
      }
      _awaitingNext = false;
      PlayerWakelock.sync(holder: widget.item.episode.id, keepOn: false);
    }
  }

  void _bindSystemPip() {
    if (!AndroidSystemPip.isSupported || _systemPipBound) return;
    AndroidSystemPip.bindPlayer(
      onPlay: () {
        unawaited(_player?.play());
        if (mounted) setState(() => _paused = false);
        unawaited(_syncWake());
      },
      onPause: () {
        unawaited(_player?.pause());
        if (mounted) setState(() => _paused = true);
        unawaited(_syncWake());
      },
    );
    unawaited(AndroidSystemPip.preferAutoEnter(enable: true));
    _systemPipBound = true;
  }

  void _unbindSystemPip() {
    if (!_systemPipBound) return;
    AndroidSystemPip.unbindPlayer();
    unawaited(AndroidSystemPip.preferAutoEnter(enable: false));
    _systemPipBound = false;
  }

  Future<void> _syncWake() async {
    final playing = widget.active &&
        !_paused &&
        !_locked &&
        (_player?.isPlaying ?? false);
    await PlayerWakelock.sync(holder: widget.item.episode.id, keepOn: playing);
    if (_systemPipBound) {
      await AndroidSystemPip.syncPlaying(playing);
    }
  }

  Future<void> _openSystemPip() async {
    final c = _player;
    if (c == null || !c.isInitialized) return;
    await c.play();
    if (!mounted) return;
    setState(() {
      _paused = false;
      _showPauseHint = false;
    });
    await _syncWake();
    if (!AndroidSystemPip.isSupported) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请点「观看完整短剧」使用小窗'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 1400),
        ),
      );
      return;
    }
    final ok = await AndroidSystemPip.enter();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('当前设备暂不支持系统画中画'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 1400),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已进入系统画中画'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 1200),
      ),
    );
  }

  Future<void> _warmNext() async {
    final next = widget.nextItem;
    if (next == null || !mounted) return;
    try {
      final info = await context.read<DramaProvider>().loadPlayInfo(next.episode.id);
      if (!mounted) return;
      final url = (info?.videoUrl.isNotEmpty == true)
          ? info!.videoUrl
          : next.episode.videoUrl;
      if (url.isEmpty || info?.locked == true) return;
      await EpisodeVideoPreload.warm(episodeId: next.episode.id, url: url);
    } catch (_) {}
  }

  Future<void> _prepare() async {
    setState(() {
      _loading = true;
      _error = null;
      _endedHandled = false;
      _danmakuItems = const [];
    });
    _player?.removeListener(_onVideoTick);
    await _player?.dispose();
    _player = null;
    if (!mounted) return;
    final dp = context.read<DramaProvider>();
    try {
      final netOk = await PlayerNetworkGuard.ensureCanPlay(context);
      if (!mounted) return;
      if (!netOk) {
        setState(() {
          _error = '网络不可用';
          _loading = false;
        });
        return;
      }
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
      final sw = Stopwatch()..start();
      final preferMk = url.toLowerCase().contains('m3u8');
      PlayHandle c;
      if (preferMk) {
        c = await openPlayHandle(url, preferMediaKit: true);
      } else {
        // 渐进式仍走预热缓存
        final taken = EpisodeVideoPreload.take(episodeId: widget.item.episode.id, url: url);
        if (taken != null) {
          if (!taken.value.isInitialized) await taken.initialize();
          c = VpPlayHandle(taken);
        } else {
          unawaited(EpisodeVideoPreload.warm(episodeId: widget.item.episode.id, url: url));
          c = await openPlayHandle(url, preferMediaKit: false);
        }
      }
      if (mounted) PlayerNetworkGuard.tipSlowIfNeeded(context, sw.elapsed);
      await c.setLooping(false);
      await c.setVolume(_muted ? 0 : 1);
      await c.setPlaybackSpeed(_baseSpeed);
      c.addListener(_onVideoTick);
      if (!mounted) {
        await c.dispose();
        return;
      }
      _player = c;
      if (widget.active) {
        await _maybeResumePosition(c, dp);
        await c.play();
        await _syncWake();
        unawaited(_warmNext());
      }
      setState(() {
        _loading = false;
        _likeCount = widget.item.episode.likeCount;
      });
      await Future.wait([_syncLikeStatus(), _syncCommentCount()]);
      if (_danmakuOn) unawaited(_loadDanmaku());
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

  Future<void> _maybeResumePosition(PlayHandle c, DramaProvider dp) async {
    final cloud = dp.continueList.map(
      (e) => (episodeId: e.resumeEpisodeId, positionSec: e.positionSec),
    );
    final sec = await PlayerProgressStore.resolveResumeSec(
      episodeId: widget.item.episode.id,
      cloudHints: cloud,
    );
    if (!mounted || sec < 5) return;
    for (var i = 0; i < 20 && c.duration.inSeconds <= 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
    }
    final dur = c.duration.inSeconds;
    if (dur > 0 && sec >= dur - 3) return;
    try {
      await c.seekTo(Duration(seconds: sec));
    } catch (_) {}
  }

  Future<void> _loadDanmaku() async {
    try {
      final resp = await CommentService(AppBootstrap.apiClient.dio)
          .episodeCommentList(episodeId: widget.item.episode.id, page: 1, size: 30);
      final raw = resp.data;
      if (!mounted) return;
      if (raw is! Map || '${raw['code']}' != '10000') {
        if (_danmakuOn) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('弹幕加载失败'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(milliseconds: 1200),
            ),
          );
        }
        return;
      }
      final data = raw['data'];
      if (data is! Map) return;
      final list = (data['list'] as List? ?? data['comments'] as List? ?? const []);
      final rawItems = <String>[];
      for (final e in list) {
        if (e is! Map) continue;
        final text = '${e['content'] ?? e['text'] ?? ''}'.trim();
        if (text.isEmpty) continue;
        rawItems.add(text);
      }
      if (rawItems.isEmpty) {
        rawItems.add('第${widget.item.episode.episodeNo}集好看');
        rawItems.add('来 ZiTok 一起追');
      }
      final durMs = (_player?.duration.inMilliseconds ?? 0).clamp(0, 1 << 30);
      final items = <DanmakuItem>[];
      for (var i = 0; i < rawItems.length; i++) {
        final at = durMs > 0 ? ((i + 1) * durMs / (rawItems.length + 1)).round() : null;
        items.add(DanmakuItem(rawItems[i], atMs: at));
      }
      items.add(DanmakuItem('第${widget.item.episode.episodeNo}集'));
      setState(() => _danmakuItems = items);
    } catch (_) {
      if (!mounted || !_danmakuOn) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('弹幕加载失败'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 1200),
        ),
      );
    }
  }

  void _onVideoTick() {
    final c = _player;
    if (c == null || !c.isInitialized || _endedHandled || !widget.active) return;
    final dur = c.duration;
    final pos = c.position;
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
    final c = _player;
    final sec = c?.isInitialized == true ? c!.position.inSeconds : 0;
    context.read<DramaProvider>().reportProgress(widget.item, positionSec: sec);
    unawaited(PlayerProgressStore.save(
      episodeId: widget.item.episode.id,
      positionSec: sec,
    ));
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
    await _player?.pause();
    if (!mounted) return;
    setState(() {
      _paused = true;
      _showPauseHint = false;
    });
    await _syncWake();
  }

  Future<void> _resumeIfActive() async {
    if (!mounted || !widget.active) return;
    await _player?.play();
    if (mounted) setState(() => _paused = false);
    await _syncWake();
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
    final c = _player;
    if (c == null || !c.isInitialized || _locked || _loading || _speedUp) return;
    if (c.isPlaying) {
      c.pause();
      setState(() {
        _paused = true;
        _showPauseHint = true;
      });
      _syncWake();
    } else {
      c.play();
      setState(() {
        _paused = false;
        _showPauseHint = true;
      });
      _syncWake();
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
    final c = _player;
    if (c == null || !c.isInitialized || _locked || _loading) return;
    c.setPlaybackSpeed(2.0);
    if (!c.isPlaying) c.play();
    setState(() {
      _speedUp = true;
      _paused = false;
      _showPauseHint = false;
    });
  }

  void _onLongPressEnd() {
    _player?.setPlaybackSpeed(_baseSpeed);
    if (mounted) setState(() => _speedUp = false);
  }

  Future<void> _toggleMute() async {
    final next = !_muted;
    await _player?.setVolume(next ? 0 : 1);
    if (mounted) setState(() => _muted = next);
  }

  Future<void> _pickSpeed() async {
    final c = _player;
    if (c == null || !c.isInitialized) return;
    final picked = await showPlayerSpeedSheet(context, current: _baseSpeed);
    if (picked == null || !mounted) return;
    await c.setPlaybackSpeed(picked);
    setState(() => _baseSpeed = picked);
  }

  Future<void> _openMore() async {
    await _player?.pause();
    if (mounted) {
      setState(() {
        _paused = true;
        _showPauseHint = false;
      });
      await _syncWake();
    }
    if (!mounted) return;
    final action = await showPlayerMoreSheet(
      context,
      muted: _muted,
      speed: _baseSpeed,
      compact: true,
    );
    if (!mounted) return;
    switch (action) {
      case PlayerMoreAction.speed:
        await _pickSpeed();
      case PlayerMoreAction.mute:
        await _toggleMute();
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请点「观看完整短剧」使用该功能'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(milliseconds: 1400),
          ),
        );
        break;
      case null:
        break;
    }
    if (mounted && widget.active && !_locked) {
      await _player?.play();
      if (mounted) setState(() => _paused = false);
      await _syncWake();
    }
  }

  @override
  void dispose() {
    _unbindSystemPip();
    _stopProgressTimer();
    _burstTimer?.cancel();
    _tapTimer?.cancel();
    _player?.removeListener(_onVideoTick);
    _player?.dispose();
    _player = null;
    PlayerWakelock.sync(holder: widget.item.episode.id, keepOn: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final inset = playerBottomInset(context, withHomeBar: true);
    final likeLabel = formatPlayerCount(_likeCount);
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: _player != null && _player!.isInitialized
              ? ExcludeSemantics(child: _player!.buildCover())
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
        PlayerDanmakuLayer(
          key: ValueKey('feed-dm-${widget.item.episode.id}'),
          items: _danmakuItems,
          handle: _player,
          enabled: _danmakuOn && !_locked && widget.active,
          paused: _paused || _awaitingNext,
        ),
        PlayerEdgeGestureLayer(
          handle: _player,
          enabled: !_locked && !_loading && !_awaitingNext,
        ),
        if (_burstPos != null) PlayerLikeBurst(localPos: _burstPos!),
        if (_loading) const Center(child: CircularProgressIndicator(color: Colors.white)),
        if (!_loading && !_locked) PlayerBufferingHint(handle: _player),
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
                label: likeLabel.isNotEmpty ? likeLabel : '点赞',
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
                danmakuOn: _danmakuOn,
                onDanmakuTap: () {
                  final next = !_danmakuOn;
                  setState(() => _danmakuOn = next);
                  if (next && _danmakuItems.isEmpty) {
                    unawaited(_loadDanmaku());
                  }
                },
              ),
              const SizedBox(height: 8),
              PlayerProgressBar(
                handle: _player,
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
                _player?.seekTo(Duration.zero);
                _player?.play();
                _endedHandled = false;
              },
            ),
          ),
      ],
    );
  }
}
