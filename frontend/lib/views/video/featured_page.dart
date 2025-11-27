import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/video_provider.dart';
import '../../theme/theme_tokens.dart';

class FeaturedPage extends StatelessWidget {
  const FeaturedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('精选'),
        actions: [IconButton(onPressed: () => context.read<VideoProvider>().refreshFeatured(), icon: const Icon(Icons.refresh))],
      ),
      body: const FeaturedBody(),
    );
  }
}

/// 精选页主体：可在发现页 Tab 内复用，避免嵌套 Scaffold
class FeaturedBody extends StatelessWidget {
  const FeaturedBody({super.key});
  @override
  Widget build(BuildContext context) {
    final vp = context.watch<VideoProvider>();
    if (vp.featured.isEmpty) {
      return Center(
        child: vp.loadingFeatured
            ? const CircularProgressIndicator()
            : ElevatedButton(onPressed: () => context.read<VideoProvider>().refreshFeatured(), child: const Text('加载精选')),
      );
    }
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.md),
            ///！！！
            child: _FeaturedHeroCard(video: vp.featured.isNotEmpty ? vp.featured.first : null),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
            child: Text('更多推荐', style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
              vp.loadMoreFeatured();
            }
            return false;
          },
          child: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                if (i < vp.featured.length) {
                  final v = vp.featured[i];
                  //！！！！！
                  return _FeaturedListItem(video: v);
                }
                return const Padding(
                  padding: EdgeInsets.all(Spacing.md),
                  child: Center(child: CircularProgressIndicator()),
                );
              },
              childCount: vp.featured.length + (vp.featuredHasMore ? 1 : 0),
            ),
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: Spacing.xl)),
      ],
    );
  }
}

class _FeaturedHeroCard extends StatelessWidget {
  final dynamic video; // 使用轻耦合以避免空列表时构造报错
  const _FeaturedHeroCard({this.video});
  @override
  Widget build(BuildContext context) {
    if (video == null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: Radii.lg,
            color: Colors.grey.shade200,
          ),
        ),
      );
    }
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: Radii.lg,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(video.coverUrl, fit: BoxFit.cover),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0x00000000), Color(0x66000000)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              left: Spacing.md,
              bottom: Spacing.md,
              right: Spacing.md,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('这是视频封面中的标题', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
                  const SizedBox(height: Spacing.sm),
                  Text('Thomas Hope · 2 weeks ago', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedListItem extends StatelessWidget {
  final dynamic video;
  const _FeaturedListItem({required this.video});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: Radii.md,
            child: Image.network(video.coverUrl, width: 120, height: 72, fit: BoxFit.cover),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('这是推荐视频的标题', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 6),
                Text('Jordan Wise  ·  125,908 views  ·  2 days ago', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
