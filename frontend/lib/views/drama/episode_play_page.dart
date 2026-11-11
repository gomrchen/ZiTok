import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:dio/dio.dart';

import '../../app.dart';
import '../../models/drama_models.dart';
import '../../providers/drama_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/comment_service.dart';
import 'episode_comments_sheet.dart';
import 'episode_label.dart';
import 'episode_picker_sheet.dart';
import 'android_system_pip.dart';
import 'player_cast_quality.dart';
import 'player_danmaku.dart';
import 'player_episode_chrome.dart';
import 'player_extras.dart';
import 'player_handle.dart';
import 'player_overlay.dart';
import 'player_pip.dart';
import 'player_poster.dart';
import 'player_runtime.dart';
import 'player_subtitle.dart';
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
  PlayHandle? _player;
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
  bool _danmakuOn = false;
  bool _subtitleOn = false;
  double _baseSpeed = 1.0;
  int _likeCount = 0;
  int _commentCount = 0;
  String? _error;
  Offset? _burstPos;
  Timer? _progressTimer;
  Timer? _burstTimer;
  Timer? _tapTimer;
  final GlobalKey _videoBoundaryKey = GlobalKey();
  String _playUrl = '';
  String _qualityLabel = '自动';
  List<VideoQualityOption> _qualities = const [];
  List<SubtitleCue> _cues = const [];
  List<DanmakuItem> _danmakuItems = const [];
  String _subtitleUrl = '';
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
      _nearEnd = false;
      _awaitingNext = false;
      if (!_paused && !_locked) _player?.play();
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
      PlayerWakelock.sync(holder: widget.episode.id, keepOn: false);
    }
  }

  void _bindSystemPip() {
    if (!AndroidSystemPip.isSupported || _systemPipBound) return;
    AndroidSystemPip.bindPlayer(
      onPlay: () {
        unawaited(_player?.play());
        if (mounted) {
          setState(() => _paused = false);
          unawaited(AndroidSystemPip.syncPlaying(true));
        }
        unawaited(_syncWake());
      },
      onPause: () {
        unawaited(_player?.pause());
        if (mounted) {
          setState(() => _paused = true);
          unawaited(AndroidSystemPip.syncPlaying(false));
        }
        unawaited(_syncWake());
      },
    );
    AndroidSystemPip.inPip.addListener(_onSystemPipChanged);
    unawaited(AndroidSystemPip.preferAutoEnter(enable: true));
    _systemPipBound = true;
  }

  void _unbindSystemPip() {
    if (!_systemPipBound) return;
    AndroidSystemPip.inPip.removeListener(_onSystemPipChanged);
    AndroidSystemPip.unbindPlayer();
    unawaited(AndroidSystemPip.preferAutoEnter(enable: false));
    _systemPipBound = false;
  }

  void _onSystemPipChanged() {
    if (!mounted) return;
    if (AndroidSystemPip.inPip.value) {
      setState(() {
        _chromeHidden = true;
        _showPauseHint = false;
      });
    } else {
      setState(() => _chromeHidden = false);
    }
  }

  @override
  void dispose() {
    _unbindSystemPip();
    _stopProgressTimer();
    _burstTimer?.cancel();
    _tapTimer?.cancel();
    _player?.removeListener(_onVideoTick);
    // 小窗已接管本集 handle：只脱钩，不销毁、不关小窗
    if (PlayerPipController.owns(widget.episode.id)) {
      _player = null;
    } else {
      PlayerPipController.closeIfOwner(widget.episode.id);
      _player?.dispose();
      _player = null;
      PlayerWakelock.sync(holder: widget.episode.id, keepOn: false);
    }
    super.dispose();
  }

  Future<void> _syncWake() async {
    final playing = widget.active &&
        !_paused &&
        !_locked &&
        (_player?.isPlaying ?? false);
    await PlayerWakelock.sync(holder: widget.episode.id, keepOn: playing);
    if (_systemPipBound) {
      await AndroidSystemPip.syncPlaying(playing);
    }
  }

  Future<void> _warmNext() async {
    final next = widget.nextEpisode;
    if (next == null || !mounted) return;
    try {
      final info = await context.read<DramaProvider>().loadPlayInfo(next.id);
      if (!mounted) return;
      final url = (info?.videoUrl.isNotEmpty == true) ? info!.videoUrl : next.videoUrl;
      if (url.isEmpty || info?.locked == true) return;
      await EpisodeVideoPreload.warm(episodeId: next.id, url: url);
    } catch (_) {}
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
      _danmakuItems = const [];
      _cues = const [];
      _subtitleUrl = '';
      _subtitleOn = false;
    });
    await _player?.dispose();
    _player = null;
    if (!mounted) return;
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
      _playUrl = url;
      _qualities = buildQualityOptions(primaryUrl: url, rawQualities: info.qualities);
      _qualityLabel = _qualities.isNotEmpty ? _qualities.first.label : '自动';
      _subtitleUrl = info.subtitleUrl.trim();
      await _loadSubtitles(_subtitleUrl);
      final sw = Stopwatch()..start();
      // 小窗还原 / 同集浮窗仍开着：认领同一路 handle
      var c = PlayerPipController.claimPendingRestore(episodeId: widget.episode.id);
      if (c == null && PlayerPipController.owns(widget.episode.id)) {
        c = PlayerPipController.takeHandleForRestore();
        PlayerPipController.close(disposeHandle: false);
      }
      if (c == null) {
        // 预热仍写磁盘缓存；播放走 media_kit（失败回退 video_player）
        unawaited(EpisodeVideoPreload.warm(episodeId: widget.episode.id, url: url));
        c = await openPlayHandle(url, preferMediaKit: true);
        if (mounted) PlayerNetworkGuard.tipSlowIfNeeded(context, sw.elapsed);
        await c.setLooping(false);
        await c.setVolume(_muted ? 0 : 1);
        await c.setPlaybackSpeed(_baseSpeed);
      }
      c.addListener(_onVideoTick);
      if (!mounted) {
        await c.dispose();
        return;
      }
      _player = c;
      // 非小窗还原时尝试续播
      final restoredFromPip = PlayerPipController.owns(widget.episode.id) ||
          c.position.inSeconds > 2;
      if (!restoredFromPip && widget.active) {
        await _maybeResumePosition(c, dp);
      }
      if (widget.active) {
        await c.play();
        await _syncWake();
        unawaited(_warmNext());
      }
      setState(() {
        _loading = false;
        _likeCount = widget.episode.likeCount;
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

  void _onVideoTick() {
    final c = _player;
    if (c == null || !c.isInitialized || !widget.active) return;
    final dur = c.duration;
    final pos = c.position;
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
    final c = _player;
    final sec = c?.isInitialized == true ? c!.position.inSeconds : 0;
    context.read<DramaProvider>().reportProgress(
          FeedItem(drama: widget.drama, episode: widget.episode),
          positionSec: sec,
        );
    unawaited(PlayerProgressStore.save(episodeId: widget.episode.id, positionSec: sec));
  }

  Future<void> _maybeResumePosition(PlayHandle c, DramaProvider dp) async {
    final cloud = dp.continueList.map(
      (e) => (episodeId: e.resumeEpisodeId, positionSec: e.positionSec),
    );
    final sec = await PlayerProgressStore.resolveResumeSec(
      episodeId: widget.episode.id,
      cloudHints: cloud,
    );
    if (!mounted || sec < 5) return;
    // 等 duration 就绪
    for (var i = 0; i < 20 && c.duration.inSeconds <= 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
    }
    final dur = c.duration.inSeconds;
    if (dur > 0 && sec >= dur - 3) return; // 已接近片尾，从头播
    if (sec >= dur && dur > 0) return;
    try {
      await c.seekTo(Duration(seconds: sec));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已从 ${_fmtResume(sec)} 续播'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1400),
        ),
      );
    } catch (_) {}
  }

  static String _fmtResume(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
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

  Future<void> _loadDanmaku() async {
    try {
      final resp = await CommentService(AppBootstrap.apiClient.dio)
          .episodeCommentList(episodeId: widget.episode.id, page: 1, size: 30);
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
        rawItems.add('第${widget.episode.episodeNo}集好看');
        rawItems.add('来 ZiTok 一起追');
      }
      final durMs = (_player?.duration.inMilliseconds ?? 0).clamp(0, 1 << 30);
      final items = <DanmakuItem>[];
      for (var i = 0; i < rawItems.length; i++) {
        final at = durMs > 0
            ? ((i + 1) * durMs / (rawItems.length + 1)).round()
            : null;
        items.add(DanmakuItem(rawItems[i], atMs: at));
      }
      // 少量自由轮播，避免静默段空场
      items.add(DanmakuItem('第${widget.episode.episodeNo}集'));
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

  Future<void> _loadSubtitles(String subtitleField) async {
    final field = subtitleField.trim();
    try {
      if (field.startsWith('http')) {
        final resp = await AppBootstrap.apiClient.dio.get<String>(
          field,
          options: Options(responseType: ResponseType.plain),
        );
        final body = resp.data ?? '';
        if (!mounted) return;
        setState(() => _cues = parseSubtitleTrack(body));
        return;
      }
      if (field.contains('-->')) {
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
      final ok = await _player?.selectEngineTrack(q) ?? false;
      if (!mounted) return;
      if (ok) {
        setState(() => _qualityLabel = q.label);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('切换清晰度轨失败'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(milliseconds: 1200),
          ),
        );
      }
      return;
    }
    if (q.url.isEmpty || q.url == _playUrl) {
      setState(() => _qualityLabel = q.label);
      return;
    }
    final pos = _player?.position ?? Duration.zero;
    setState(() {
      _loading = true;
      _qualityLabel = q.label;
      _playUrl = q.url;
    });
    try {
      final old = _player;
      old?.removeListener(_onVideoTick);
      final c = await openPlayHandle(q.url, preferMediaKit: true);
      await c.setLooping(false);
      await c.setVolume(_muted ? 0 : 1);
      await c.setPlaybackSpeed(_baseSpeed);
      await c.seekTo(pos);
      c.addListener(_onVideoTick);
      if (!mounted) {
        await c.dispose();
        return;
      }
      _player = c;
      await old?.dispose();
      if (widget.active && !_paused) await c.play();
      setState(() => _loading = false);
      await _syncWake();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$e';
        });
      }
    }
  }

  List<VideoQualityOption> _mergedQualityOptions() {
    final base = _qualities.isEmpty
        ? buildQualityOptions(primaryUrl: _playUrl)
        : List<VideoQualityOption>.from(_qualities);
    final tracks = _player?.engineTrackOptions() ?? const [];
    if (tracks.isEmpty) return base;
    // 服务端多 URL 优先；引擎轨附在后面（去重 label）
    final labels = base.map((e) => e.label).toSet();
    for (final t in tracks) {
      if (labels.add(t.label)) base.add(t);
    }
    return base;
  }

  Future<void> _openPip() async {
    final c = _player;
    if (c == null || !c.isInitialized) return;
    await c.play();
    if (!mounted) return;

    // Android：优先系统画中画（退后台级）；失败再走应用内小窗
    if (AndroidSystemPip.isSupported) {
      final ok = await AndroidSystemPip.enter();
      if (!mounted) return;
      if (ok) {
        setState(() {
          _paused = false;
          _showPauseHint = false;
          _chromeHidden = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已进入系统画中画'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(milliseconds: 1200),
          ),
        );
        await _syncWake();
        return;
      }
    }

    // 应用内小窗：接管后离页续播
    _player?.removeListener(_onVideoTick);
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
    _player = null;
    setState(() {
      _paused = false;
      _showPauseHint = false;
      _chromeHidden = true;
    });
    await PlayerWakelock.sync(holder: 'pip', keepOn: true);
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
    await _player?.pause();
    if (!mounted) return;
    setState(() {
      _paused = true;
      _showPauseHint = false;
    });
    await _syncWake();
  }

  Future<void> _resumeIfActive() async {
    if (!mounted || !widget.active || _locked) return;
    await _player?.play();
    if (mounted) setState(() => _paused = false);
    await _syncWake();
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
    final c = _player;
    if (c == null || !c.isInitialized) return;
    final next = !_muted;
    await c.setVolume(next ? 0 : 1);
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
      subtitleOn: _subtitleOn,
      qualityLabel: _qualityLabel,
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
      case PlayerMoreAction.quality:
        final q = await showQualitySheet(
          context,
          options: _mergedQualityOptions(),
          currentUrl: _playUrl,
          currentTrackId: _player?.currentVideoTrackId,
        );
        if (q != null) await _switchQuality(q);
      case PlayerMoreAction.cast:
        await showCastSheet(
          context,
          playUrl: _playUrl,
          deepLink: 'zitok://drama/${widget.drama.id}?ep=${widget.episode.id}',
        );
      case PlayerMoreAction.subtitle:
        final next = !_subtitleOn;
        final engine = _player?.supportsEngineSubtitle == true;
        final canEngine = engine &&
            ((_player?.hasEngineSubtitle ?? false) || _subtitleUrl.startsWith('http'));
        final canOverlay = _cues.isNotEmpty;
        if (next && !canEngine && !canOverlay) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('本集暂无字幕'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(milliseconds: 1400),
            ),
          );
        } else {
          if (engine) {
            await _player?.setEngineSubtitle(
              on: next && canEngine,
              externalUrl: _subtitleUrl.startsWith('http') ? _subtitleUrl : null,
            );
          }
          setState(() => _subtitleOn = next && (canEngine || canOverlay));
        }
      case PlayerMoreAction.poster:
        await captureAndSharePoster(
          context,
          boundaryKey: _videoBoundaryKey,
          title: widget.drama.title,
          episodeLabel: '第${widget.episode.episodeNo}集',
          deepLink: 'zitok://drama/${widget.drama.id}?ep=${widget.episode.id}',
          ready: _player?.isInitialized == true && !_loading,
        );
      case PlayerMoreAction.pip:
        await _openPip();
      case null:
        break;
    }
    if (mounted &&
        widget.active &&
        !_locked &&
        !PlayerPipController.isOpen &&
        action != PlayerMoreAction.pip) {
      await _player?.play();
      if (mounted) setState(() => _paused = false);
      await _syncWake();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dockH = playerEpisodeDockHeight(context);
    final next = widget.nextEpisode;
    final likeLabel = formatPlayerCount(_likeCount);
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
                : (_player != null && _player!.isInitialized
                    ? ExcludeSemantics(child: _player!.buildCover())
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
              _onSingleTap();
            },
            onDoubleTapDown: _onDoubleTap,
            onLongPressStart: (_) => _onLongPressStart(),
            onLongPressEnd: (_) => _onLongPressEnd(),
            onLongPressCancel: _onLongPressEnd,
            child: const SizedBox.expand(),
          ),
        ),
        PlayerDanmakuLayer(
          key: ValueKey('dm-${widget.episode.id}'),
          items: _danmakuItems,
          handle: _player,
          enabled: _danmakuOn && !_locked && widget.active,
          paused: _paused || _awaitingNext,
        ),
        PlayerSubtitleLayer(
          handle: _player,
          cues: _cues,
          // media_kit 引擎字幕烧屏时不叠 overlay，避免双字幕
          enabled: _subtitleOn && !_locked && _cues.isNotEmpty && !(_player?.supportsEngineSubtitle == true),
        ),
        PlayerEdgeGestureLayer(
          handle: _player,
          enabled: !_locked && !_loading && !_awaitingNext,
        ),
        if (_burstPos != null) PlayerLikeBurst(localPos: _burstPos!),
        if (showChrome)
          const Positioned(top: 0, left: 0, right: 0, height: 140, child: PlayerTopScrim()),
        if (showChrome)
          Positioned(left: 0, right: 0, bottom: dockH, height: 280, child: const PlayerBottomScrim()),
        if (_loading) const Center(child: CircularProgressIndicator(color: Colors.white)),
        if (!_loading && !_locked)
          PlayerBufferingHint(handle: _player, enabled: !pipOn),
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
                await _pauseForOverlay();
                await widget.onOpenPicker();
                await _resumeIfActive();
              },
              onToggleChrome: _openPip,
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
