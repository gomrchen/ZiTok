import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../app.dart';
import '../../models/drama_models.dart';
import '../../providers/drama_provider.dart';
import '../../services/comment_service.dart';
import '../../widgets/cover_video.dart';
import 'episode_comments_sheet.dart';
import 'episode_label.dart';
import 'episode_picker_sheet.dart';
import 'player_overlay.dart';
import 'unlock_sheet.dart';

/// 剧场/详情进入的全屏播放：上下滑切集、点击暂停/播放
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
    final bal = context.watch<DramaProvider>().wallet?.balance;
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
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
              return _EpisodeSlide(
                key: ValueKey('play-ep-${_episodes[i].id}'),
                drama: widget.drama,
                episode: _episodes[i],
                active: i == _index,
                onOpenComments: () => showEpisodeCommentsSheet(context, episodeId: _episodes[i].id),
                onOpenPicker: _openPicker,
              );
            },
          ),
          const Positioned(top: 0, left: 0, right: 0, height: 140, child: PlayerTopScrim()),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 2, 12, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                    ),
                    const Spacer(),
                    if (bal != null) PlayerCoinChip(balance: bal),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EpisodeSlide extends StatefulWidget {
  final Drama drama;
  final Episode episode;
  final bool active;
  final Future<void> Function() onOpenComments;
  final VoidCallback onOpenPicker;

  const _EpisodeSlide({
    super.key,
    required this.drama,
    required this.episode,
    required this.active,
    required this.onOpenComments,
    required this.onOpenPicker,
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
  int _likeCount = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(covariant _EpisodeSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      if (!_locked && _controller != null && !_paused) {
        _controller!.play();
      }
    } else if (!widget.active && oldWidget.active) {
      _controller?.pause();
    }
  }

  @override
  void dispose() {
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
      final c = VideoPlayerController.networkUrl(Uri.parse(info.videoUrl));
      await c.initialize();
      c.setLooping(true);
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
      await _syncLikeStatus();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _syncLikeStatus() async {
    try {
      final resp = await CommentService(AppBootstrap.apiClient.dio)
          .episodeLikeStatus(episodeId: widget.episode.id);
      final raw = resp.data;
      if (!mounted || raw is! Map) return;
      if ('${raw['code']}' != '10000') return;
      final data = raw['data'];
      if (data is! Map) return;
      setState(() {
        _liked = data['liked'] == true;
        final c = data['like_count'];
        if (c is num) _likeCount = c.toInt();
      });
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
    try {
      final resp = await CommentService(AppBootstrap.apiClient.dio)
          .likeEpisode(episodeId: widget.episode.id);
      if (!mounted) return;
      final raw = resp.data;
      if (raw is Map && '${raw['code']}' == '10000' && raw['data'] is Map) {
        final data = Map<String, dynamic>.from(raw['data'] as Map);
        setState(() {
          _liked = data['liked'] == true;
          final c = data['like_count'];
          if (c is num) {
            _likeCount = c.toInt();
          } else {
            _likeCount = (_likeCount + (_liked ? 1 : -1)).clamp(0, 1 << 30);
          }
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

  void _togglePause() {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _locked || _loading) return;
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

  @override
  Widget build(BuildContext context) {
    final inset = playerBottomInset(context, withHomeBar: false);
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
            onTap: _togglePause,
            child: const SizedBox.expand(),
          ),
        ),
        const Positioned(left: 0, right: 0, bottom: 0, height: 220, child: PlayerBottomScrim()),
        if (_loading) const Center(child: CircularProgressIndicator(color: Colors.white)),
        if (_error != null)
          Center(child: FilledButton(onPressed: _prepare, child: const Text('重试'))),
        if (_locked)
          ColoredBox(
            color: Colors.black54,
            child: Center(
              child: FilledButton(onPressed: _unlock, child: const Text('解锁本集')),
            ),
          ),
        if (_showPauseHint && !_locked && !_loading) PlayerPauseHint(paused: _paused),
        Positioned(
          right: 6,
          bottom: inset + 72,
          child: Column(
            children: [
              PlayerSideAction(
                icon: _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                label: _likeCount > 0 ? '$_likeCount' : '点赞',
                iconColor: _liked ? kPlayerPrimary : Colors.white,
                onTap: _toggleLike,
              ),
              PlayerSideAction(
                icon: Icons.chat_bubble_outline_rounded,
                label: '评论',
                onTap: () async {
                  await _controller?.pause();
                  setState(() {
                    _paused = true;
                    _showPauseHint = false;
                  });
                  await widget.onOpenComments();
                  if (mounted && widget.active && !_locked) {
                    await _controller?.play();
                    setState(() => _paused = false);
                  }
                },
              ),
              PlayerSideAction(
                icon: Icons.list_alt_rounded,
                label: '选集',
                onTap: widget.onOpenPicker,
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
                title: widget.drama.title,
                subtitle: episodeSubtitle(widget.episode, category: widget.drama.category),
              ),
              const SizedBox(height: 6),
              PlayerProgressBar(controller: _controller),
            ],
          ),
        ),
      ],
    );
  }
}
