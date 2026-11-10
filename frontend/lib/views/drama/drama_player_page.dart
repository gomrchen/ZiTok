import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../models/drama_models.dart';
import '../../providers/drama_provider.dart';
import '../../app.dart';
import '../../services/comment_service.dart';
import '../../widgets/cover_video.dart';
import 'unlock_sheet.dart';
import 'episode_comments_sheet.dart';
import 'episode_label.dart';
import 'episode_picker_sheet.dart';
import 'episode_play_page.dart';
import 'player_overlay.dart';

/// 首页竖屏连播：一屏一集，上滑下一集。
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
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DramaProvider>();
    // 作为 HomeShell 子页：不要再套 Scaffold，避免嵌套裁切/黑边
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
          return _EpisodeSlide(
            key: ValueKey('ep-${item.episode.id}-$_index'),
            item: item,
            active: i == _index,
          );
        },
      ),
    );
  }
}

class _EpisodeSlide extends StatefulWidget {
  final FeedItem item;
  final bool active;

  const _EpisodeSlide({super.key, required this.item, required this.active});

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
      _controller?.play();
    } else if (!widget.active && oldWidget.active) {
      _controller?.pause();
    }
  }

  Future<void> _prepare() async {
    setState(() {
      _loading = true;
      _error = null;
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
      c.setLooping(true);
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
          .episodeLikeStatus(episodeId: widget.item.episode.id);
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
          .likeEpisode(episodeId: widget.item.episode.id);
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
      // 兼容旧网关：无 data 时本地翻转
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

  Future<void> _showUnlock() async {
    final item = widget.item;
    final ok = await showUnlockSheet(
      context,
      episodeId: item.episode.id,
      unlockPrice: item.episode.unlockPrice,
      bundlePrice: item.drama.bundlePrice,
      dramaId: item.drama.id,
    );
    if (ok == true && mounted) {
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
  void dispose() {
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
            onTap: _togglePause,
            child: const SizedBox.expand(),
          ),
        ),
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
              child: FilledButton(
                onPressed: _showUnlock,
                child: const Text('解锁本集'),
              ),
            ),
          ),
        const Positioned(left: 0, right: 0, bottom: 0, height: 260, child: PlayerBottomScrim()),
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
                  if (!context.mounted) return;
                  await showEpisodeCommentsSheet(context, episodeId: item.episode.id);
                  if (widget.active && mounted) {
                    await _controller?.play();
                    setState(() => _paused = false);
                  }
                },
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
              const SizedBox(height: 6),
              PlayerProgressBar(controller: _controller),
            ],
          ),
        ),
      ],
    );
  }
}
