import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/drama_provider.dart';
import '../home/shell_surface.dart';

class WatchingPage extends StatefulWidget {
  const WatchingPage({super.key});

  @override
  State<WatchingPage> createState() => _WatchingPageState();
}

class _WatchingPageState extends State<WatchingPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DramaProvider>().refreshWatching();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DramaProvider>();
    return AnnotatedRegion(
      value: ShellSurface.systemUi,
      child: Scaffold(
        backgroundColor: ShellSurface.canvas,
        appBar: ShellSurface.appBar(title: '追剧'),
        body: RefreshIndicator(
          color: ShellSurface.coral,
          backgroundColor: ShellSurface.card,
          onRefresh: () => dp.refreshWatching(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              ShellSurface.pagePad,
              8,
              ShellSurface.pagePad,
              20,
            ),
            children: [
              Text('继续观看', style: ShellSurface.sectionTitle),
              const SizedBox(height: 12),
              if (dp.continueList.isEmpty)
                const _EmptyHint(text: '暂无进度，去剧场挑一部开追')
              else
                ...dp.continueList.map((c) {
                  final drama = c.drama;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _WatchRow(
                      coverUrl: drama?.coverUrl ?? '',
                      title: drama?.title ?? '未知剧',
                      subtitle: '看到第${c.episodeNo}集',
                      accentSubtitle: true,
                      onTap: drama == null ? null : () => context.push('/drama/${drama.id}'),
                    ),
                  );
                }),
              const SizedBox(height: ShellSurface.sectionGap),
              Text('我的收藏', style: ShellSurface.sectionTitle),
              const SizedBox(height: 12),
              if (dp.favorites.isEmpty)
                const _EmptyHint(text: '还没有追剧，点进播放页即可收藏')
              else
                ...dp.favorites.map(
                  (d) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _WatchRow(
                      coverUrl: d.coverUrl,
                      title: d.title,
                      subtitle: '${d.totalEpisodes}集${d.category.isEmpty ? '' : ' · ${d.category}'}',
                      onTap: () => context.push('/drama/${d.id}'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: ShellSurface.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ShellSurface.line),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: ShellSurface.caption.copyWith(fontSize: 13),
      ),
    );
  }
}

class _WatchRow extends StatelessWidget {
  final String coverUrl;
  final String title;
  final String subtitle;
  final bool accentSubtitle;
  final VoidCallback? onTap;

  const _WatchRow({
    required this.coverUrl,
    required this.title,
    required this.subtitle,
    this.accentSubtitle = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: ShellSurface.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ShellSurface.line),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 58,
                  height: 78,
                  child: coverUrl.isNotEmpty
                      ? Image.network(coverUrl, fit: BoxFit.cover)
                      : const ColoredBox(color: Color(0xFFD9D4CC)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: ShellSurface.bodyStrong),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: accentSubtitle
                          ? ShellSurface.caption.copyWith(
                              color: ShellSurface.coral.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w700,
                            )
                          : ShellSurface.caption,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: ShellSurface.ink.withValues(alpha: 0.28)),
            ],
          ),
        ),
      ),
    );
  }
}
