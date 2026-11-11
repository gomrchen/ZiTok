import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/drama_models.dart';
import '../../providers/drama_provider.dart';
import '../home/shell_surface.dart';

class SearchResultsPage extends StatefulWidget {
  final String keywords;
  const SearchResultsPage({super.key, required this.keywords});

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  List<Drama> _list = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await context.read<DramaProvider>().dramaService.search(q: widget.keywords);
      final raw = resp.data;
      if (raw is! Map || '${raw['code']}' != '10000') {
        throw Exception('搜索失败');
      }
      final data = Map<String, dynamic>.from(raw['data'] as Map? ?? {});
      setState(() {
        _list = (data['list'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Drama.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ShellSurface.canvasOf(context),
      appBar: ShellSurface.appBar(
        title: '搜索：${widget.keywords}',
        context: context,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _list.isEmpty
                  ? const Center(child: Text('没有找到相关短剧'))
                  : ListView.separated(
                      itemCount: _list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final d = _list[i];
                        return ListTile(
                          leading: d.coverUrl.isEmpty
                              ? const SizedBox(width: 48, height: 64)
                              : Image.network(d.coverUrl, width: 48, height: 64, fit: BoxFit.cover),
                          title: Text(d.title),
                          subtitle: Text('${d.category} · ${d.totalEpisodes}集'),
                          onTap: () => context.push('/drama/${d.id}'),
                        );
                      },
                    ),
    );
  }
}
