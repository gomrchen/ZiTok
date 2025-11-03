import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../providers/video_provider.dart';
import '../../theme/theme_tokens.dart';
import 'featured_page.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});
  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> with TickerProviderStateMixin {
  late TabController _tab;
  int _currentRecommendIndex = 0;
  final Map<String, VideoPlayerController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _tab.dispose();
    super.dispose();
  }

  Future<void> _playIndex(List videos, int index) async {
    if (index < 0 || index >= videos.length) return;
    setState(() => _currentRecommendIndex = index);
    final v = videos[index];
    // 释放上一条
    for (final entry in _controllers.entries) {
      if (entry.key != v.id) entry.value.pause();
    }
    // 当前控制器
    var ctrl = _controllers[v.id];
    if (ctrl == null) {
      ctrl = VideoPlayerController.networkUrl(Uri.parse(v.videoUrl));
      _controllers[v.id] = ctrl;
      await ctrl.initialize();
    }
    ctrl.setLooping(true);
    await ctrl.play();
  }

  @override
  Widget build(BuildContext context) {
    final vp = context.watch<VideoProvider>();
    return Scaffold(
      appBar: AppBar(
        // 不显示“发现”标题，仅保留底部 TabBar
        toolbarHeight: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        elevation: 0,
        bottom: TabBar(
          controller: _tab,
          tabs: const [Tab(text: '精选'), Tab(text: '推荐')],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // 精选模式：复用 FeaturedBody（无嵌套 Scaffold）
          const FeaturedBody(),
          // 推荐模式：竖直PageView全屏播放
          _RecommendFullScreen(videos: vp.discover, onIndexChanged: (i) => _playIndex(vp.discover, i)),
        ],
      ),
      // 底部导航由 Router 壳提供，页面内不再渲染
    );
  }
}

class _RecommendFullScreen extends StatefulWidget {
  final List videos;
  final ValueChanged<int> onIndexChanged;
  const _RecommendFullScreen({required this.videos, required this.onIndexChanged});
  @override
  State<_RecommendFullScreen> createState() => _RecommendFullScreenState();
}

class _RecommendFullScreenState extends State<_RecommendFullScreen> {
  late final PageController _pageController;
  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      scrollDirection: Axis.vertical,
      controller: _pageController,
      itemCount: widget.videos.length,
      onPageChanged: widget.onIndexChanged,
      itemBuilder: (context, i) {
        final v = widget.videos[i];
        return _FullScreenVideoItem(video: v);
      },
    );
  }
}

class _FullScreenVideoItem extends StatefulWidget {
  final dynamic video;
  const _FullScreenVideoItem({required this.video});
  @override
  State<_FullScreenVideoItem> createState() => _FullScreenVideoItemState();
}

class _FullScreenVideoItemState extends State<_FullScreenVideoItem> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.video.videoUrl));
    _controller.initialize().then((_) {
      if (mounted) setState(() => _initialized = true);
      _controller.setLooping(true);
      _controller.play();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        _initialized
            ? FittedBox(fit: BoxFit.cover, child: SizedBox(width: _controller.value.size.width, height: _controller.value.size.height, child: VideoPlayer(_controller)))
            : const Center(child: CircularProgressIndicator()),
        // 右侧操作栏
        Positioned(
          right: Spacing.md,
          top: MediaQuery.of(context).size.height * 0.25,
          child: Column(
            children: [
              _ActionIcon(icon: Icons.favorite_border, label: '${widget.video.likes}k'),
              const SizedBox(height: Spacing.md),
              const _ActionIcon(icon: Icons.chat_bubble_outline, label: '1.2k'),
              const SizedBox(height: Spacing.md),
              const _ActionIcon(icon: Icons.share_outlined, label: '4.6k'),
              const SizedBox(height: Spacing.md),
              const _ActionIcon(icon: Icons.more_horiz, label: ''),
            ],
          ),
        ),
        // 底部文案
        Positioned(
          left: Spacing.md,
          right: Spacing.md,
          bottom: Spacing.xl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('@${widget.video.uid ?? '未知作者'}', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white)),
              const SizedBox(height: 8),
              Text('Video description here. #hashtag #anothertag', style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
              const SizedBox(height: 8),
              Text('Original Audio · song name', style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ActionIcon({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x33000000)),
          child: Icon(icon, color: Colors.white),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white)),
        ],
      ],
    );
  }
}