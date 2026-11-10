import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n_ext.dart';
import '../../providers/drama_provider.dart';
import '../home/shell_surface.dart';

class TheaterPage extends StatefulWidget {
  final String? initialCategory;

  const TheaterPage({super.key, this.initialCategory});

  @override
  State<TheaterPage> createState() => _TheaterPageState();
}

class _TheaterPageState extends State<TheaterPage> {
  String? _category;

  /// API 分类值（与库内 category 一致）；展示文案走 l10n
  static const _apiCats = [null, '甜宠', '古装', '青春'];

  @override
  void initState() {
    super.initState();
    final seed = (widget.initialCategory ?? '').trim();
    if (seed.isNotEmpty && seed != '全部') {
      _category = seed;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DramaProvider>().refreshTheater(category: _category);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labels = {
      null: l10n.theaterCatAll,
      '甜宠': l10n.theaterCatRomance,
      '古装': l10n.theaterCatCostume,
      '青春': l10n.theaterCatYouth,
    };
    final dp = context.watch<DramaProvider>();
    final cats = <String?>[
      ..._apiCats,
      if (_category != null && !_apiCats.contains(_category)) _category,
    ];
    return AnnotatedRegion(
      value: ShellSurface.systemUiOf(context),
      child: Scaffold(
        backgroundColor: ShellSurface.canvasOf(context),
        appBar: ShellSurface.appBar(
          title: l10n.theaterTitle,
          context: context,
          actions: [
            IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: () => context.push('/search'),
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: ShellSurface.pagePad),
                itemCount: cats.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final c = cats[i];
                  final selected = _category == c;
                  return _CategoryPill(
                    label: labels[c] ?? c ?? l10n.theaterCatAll,
                    selected: selected,
                    onTap: () {
                      setState(() => _category = c);
                      dp.refreshTheater(category: _category);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: dp.loadingTheater && dp.theater.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: ShellSurface.coral))
                  : RefreshIndicator(
                      color: ShellSurface.coral,
                      backgroundColor: ShellSurface.cardOf(context),
                      onRefresh: () => dp.refreshTheater(category: _category),
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          ShellSurface.pagePad,
                          4,
                          ShellSurface.pagePad,
                          12,
                        ),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.58,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 14,
                        ),
                        itemCount: dp.theater.length,
                        itemBuilder: (_, i) {
                          final d = dp.theater[i];
                          return InkWell(
                            onTap: () => context.push('/drama/${d.id}'),
                            borderRadius: BorderRadius.circular(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: ShellSurface.inkOf(context)
                                              .withValues(alpha: 0.06),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: d.coverUrl.isEmpty
                                          ? ColoredBox(
                                              color: ShellSurface.isDark(context)
                                                  ? const Color(0xFF1F2937)
                                                  : const Color(0xFFD9D4CC),
                                            )
                                          : Image.network(
                                              d.coverUrl,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: double.infinity,
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  d.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: ShellSurface.bodyStrongOf(context)
                                      .copyWith(fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${l10n.watchingEpisodes(d.totalEpisodes)} · ${d.category}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: ShellSurface.captionOf(context),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ink = ShellSurface.inkOf(context);
    final selectedFg = ShellSurface.isDark(context) ? ShellSurface.canvasDark : Colors.white;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            color: selected ? ink : ShellSurface.cardOf(context),
            border: Border.all(
              color: selected ? ink : ShellSurface.lineOf(context),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(Icons.check_rounded, size: 14, color: selectedFg),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? selectedFg : ShellSurface.mutedOf(context),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
