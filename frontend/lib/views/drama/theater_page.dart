import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/drama_provider.dart';
import '../home/shell_surface.dart';

class TheaterPage extends StatefulWidget {
  const TheaterPage({super.key});

  @override
  State<TheaterPage> createState() => _TheaterPageState();
}

class _TheaterPageState extends State<TheaterPage> {
  String? _category;

  static const categories = ['全部', '甜宠', '古装', '青春'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DramaProvider>().refreshTheater();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DramaProvider>();
    return AnnotatedRegion(
      value: ShellSurface.systemUi,
      child: Scaffold(
        backgroundColor: ShellSurface.canvas,
        appBar: ShellSurface.appBar(
          title: '剧场',
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
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final c = categories[i];
                  final selected = (_category == null && c == '全部') || _category == c;
                  return _CategoryPill(
                    label: c,
                    selected: selected,
                    onTap: () {
                      setState(() => _category = c == '全部' ? null : c);
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
                      backgroundColor: ShellSurface.card,
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
                                          color: ShellSurface.ink.withValues(alpha: 0.06),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: d.coverUrl.isEmpty
                                          ? const ColoredBox(color: Color(0xFFD9D4CC))
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
                                  style: ShellSurface.bodyStrong.copyWith(fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${d.totalEpisodes}集 · ${d.category}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: ShellSurface.caption,
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            color: selected ? ShellSurface.ink : ShellSurface.card,
            border: Border.all(
              color: selected ? ShellSurface.ink : ShellSurface.line,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : ShellSurface.muted,
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
