import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/drama_provider.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('追剧')),
      body: RefreshIndicator(
        onRefresh: () => dp.refreshWatching(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('继续观看', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (dp.continueList.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('暂无进度', style: TextStyle(color: Colors.grey)),
              )
            else
              ...dp.continueList.map((c) {
                final title = c.drama?.title ?? '未知剧';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 56,
                      height: 80,
                      child: c.drama?.coverUrl.isNotEmpty == true
                          ? Image.network(c.drama!.coverUrl, fit: BoxFit.cover)
                          : Container(color: Colors.grey.shade300),
                    ),
                  ),
                  title: Text(title),
                  subtitle: Text('看到第${c.episodeNo}集'),
                  onTap: () {
                    if (c.drama != null) context.push('/drama/${c.drama!.id}');
                  },
                );
              }),
            const SizedBox(height: 16),
            const Text('我的收藏', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (dp.favorites.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('还没有追剧', style: TextStyle(color: Colors.grey)),
              )
            else
              ...dp.favorites.map((d) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 56,
                        height: 80,
                        child: d.coverUrl.isNotEmpty
                            ? Image.network(d.coverUrl, fit: BoxFit.cover)
                            : Container(color: Colors.grey.shade300),
                      ),
                    ),
                    title: Text(d.title),
                    subtitle: Text('${d.totalEpisodes}集'),
                    onTap: () => context.push('/drama/${d.id}'),
                  )),
          ],
        ),
      ),
    );
  }
}
