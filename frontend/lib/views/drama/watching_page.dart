import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n_ext.dart';
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
    final l10n = context.l10n;
    return AnnotatedRegion(
      value: ShellSurface.systemUiOf(context),
      child: Scaffold(
        backgroundColor: ShellSurface.canvasOf(context),
        appBar: ShellSurface.appBar(title: l10n.watchingTitle, context: context),
        body: RefreshIndicator(
          color: ShellSurface.coral,
          backgroundColor: ShellSurface.cardOf(context),
          onRefresh: () => dp.refreshWatching(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              ShellSurface.pagePad,
              8,
              ShellSurface.pagePad,
              20,
            ),
            children: [
              Text(l10n.profileContinue, style: ShellSurface.sectionTitleOf(context)),
              const SizedBox(height: 12),
              if (dp.continueList.isEmpty)
                _EmptyHint(text: l10n.watchingEmptyContinue)
              else
                ...dp.continueList.map((c) {
                  final drama = c.drama;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _WatchRow(
                      coverUrl: drama?.coverUrl ?? '',
                      title: drama?.title ?? l10n.watchingUnknownDrama,
                      subtitle: l10n.profileEpisodeSeen(c.episodeNo),
                      accentSubtitle: true,
                      onTap: drama == null
                          ? null
                          : () {
                              final ep = c.resumeEpisodeId;
                              context.push(
                                ep > 0 ? '/drama/${drama.id}?ep=$ep' : '/drama/${drama.id}',
                              );
                            },
                    ),
                  );
                }),
              const SizedBox(height: ShellSurface.sectionGap),
              Text(l10n.profileFavorites, style: ShellSurface.sectionTitleOf(context)),
              const SizedBox(height: 12),
              if (dp.favorites.isEmpty)
                _EmptyHint(text: l10n.watchingEmptyFav)
              else
                ...dp.favorites.map(
                  (d) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _WatchRow(
                      coverUrl: d.coverUrl,
                      title: d.title,
                      subtitle:
                          '${l10n.watchingEpisodes(d.totalEpisodes)}${d.category.isEmpty ? '' : ' · ${d.category}'}',
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
        color: ShellSurface.cardOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ShellSurface.lineOf(context)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: ShellSurface.captionOf(context).copyWith(fontSize: 13),
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
            color: ShellSurface.cardOf(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ShellSurface.lineOf(context)),
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
                      : ColoredBox(
                          color: ShellSurface.isDark(context)
                              ? const Color(0xFF1F2937)
                              : const Color(0xFFD9D4CC),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ShellSurface.bodyStrongOf(context),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: accentSubtitle
                          ? ShellSurface.captionOf(context).copyWith(
                              color: ShellSurface.coral.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w700,
                            )
                          : ShellSurface.captionOf(context),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: ShellSurface.inkOf(context).withValues(alpha: 0.28),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
