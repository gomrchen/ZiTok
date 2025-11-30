import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/video_provider.dart';
import '../../models/video.dart';
import '../../theme/theme_tokens.dart';
import 'package:go_router/go_router.dart';

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
class FeaturedBody extends StatefulWidget {
  const FeaturedBody({super.key});
  @override
  State<FeaturedBody> createState() => _FeaturedBodyState();
}

class _FeaturedBodyState extends State<FeaturedBody> {
  List<dynamic> _items = [];
  bool _loading = false;
  bool _hasMore = true;
  String? _error;
  int _page = 1; // 分页游标
  static const int _pageSize = 20;

  String _fmt(int c) {
    if (c >= 1000000) return '${(c / 1000000).toStringAsFixed(1)}M';
    if (c >= 1000) return '${(c / 1000).toStringAsFixed(1)}k';
    return '$c';
  }

  Future<void> _fetch({bool refresh = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    if (refresh) {
      _page = 1;
      _items = [];
      _hasMore = true;
      _error = null;
    }
    try {
      final repo = context.read<VideoProvider>().repo;
      debugPrint('FeaturedBody: fetch page=$_page size=$_pageSize');
      final res = await repo.fetchFeatured(VideoQuery(page: _page, pageSize: _pageSize));
      if (refresh) {
        _items = res.items;
      } else {
        _items.addAll(res.items);
      }
      _hasMore = res.hasMore;
      _page += 1;
      debugPrint('FeaturedBody: fetched=${res.items.length} total=${_items.length} hasMore=$_hasMore');
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch(refresh: true));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text('加载失败'), const SizedBox(height: 8), ElevatedButton(onPressed: () => _fetch(refresh: true), child: const Text('重试'))]));
    }
    if (_items.isEmpty) {
      return Center(child: ElevatedButton(onPressed: () => _fetch(refresh: true), child: const Text('加载精选')));
    }
    return RefreshIndicator(
      onRefresh: () => _fetch(refresh: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (_hasMore && !_loading && n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
            // 接近底部，加载更多
            Future.microtask(() => _fetch());
          }
          return false;
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.md),
                child: _FeaturedHeroCard(video: _items.isNotEmpty ? _items.first : null),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                child: Text('更多推荐', style: Theme.of(context).textTheme.titleMedium),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  if (i < _items.length) {
                    final v = _items[i];
                    return _FeaturedListItem(video: v, fmt: _fmt);
                  }
                  return const Padding(
                    padding: EdgeInsets.all(Spacing.md),
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
                childCount: _items.length + (_hasMore ? 1 : 0),
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: Spacing.xl)),
          ],
        ),
      ),
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
      child: InkWell(
        onTap: () => context.go('/video/${video.id}'),
        child: ClipRRect(
          borderRadius: Radii.lg,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(imageUrl: video.coverUrl ?? '', fit: BoxFit.cover, placeholder: (c, _) => const Center(child: CircularProgressIndicator()), errorWidget: (c, _, __) => const ColoredBox(color: Colors.black12)),
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
                    Text(video.title ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
                    const SizedBox(height: Spacing.sm),
                    Row(
                      children: [
                        const Icon(Icons.favorite, size: 14, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text('${video.likes ?? 0}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
                        const SizedBox(width: 12),
                        const Icon(Icons.chat_bubble_outline, size: 14, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text('${video.commentCount ?? 0}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturedListItem extends StatelessWidget {
  final dynamic video;
  final String Function(int) fmt;
  const _FeaturedListItem({required this.video, required this.fmt});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
      child: InkWell(
        onTap: () => context.go('/video/${video.id}'),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: Radii.md,
              child: CachedNetworkImage(imageUrl: video.coverUrl ?? '', width: 120, height: 72, fit: BoxFit.cover, placeholder: (c, _) => const Center(child: CircularProgressIndicator()), errorWidget: (c, _, __) => const ColoredBox(color: Colors.black12)),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(video.title ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  Text('${video.intro ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.favorite, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(fmt(video.likes ?? 0), style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(width: 12),
                      Icon(Icons.chat_bubble_outline, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(fmt(video.commentCount ?? 0), style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
