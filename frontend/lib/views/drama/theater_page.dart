import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/drama_provider.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('剧场'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final c = categories[i];
                final selected = (_category == null && c == '全部') || _category == c;
                return ChoiceChip(
                  label: Text(c),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _category = c == '全部' ? null : c);
                    dp.refreshTheater(category: _category);
                  },
                );
              },
            ),
          ),
          Expanded(
            child: dp.loadingTheater && dp.theater.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => dp.refreshTheater(category: _category),
                    child: GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.62,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: dp.theater.length,
                      itemBuilder: (_, i) {
                        final d = dp.theater[i];
                        return InkWell(
                          onTap: () => context.push('/drama/${d.id}'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: d.coverUrl.isEmpty
                                      ? Container(color: Colors.grey.shade300)
                                      : Image.network(d.coverUrl, fit: BoxFit.cover, width: double.infinity),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('${d.totalEpisodes}集 · ${d.category}', style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
