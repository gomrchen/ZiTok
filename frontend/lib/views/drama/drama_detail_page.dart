import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/drama_models.dart';
import '../../providers/drama_provider.dart';
import 'episode_play_page.dart';
import 'unlock_sheet.dart';

const _kPrimary = Color(0xFF2ED3BE);
const _kCell = Color(0xFF232A36);

class DramaDetailPage extends StatefulWidget {
  final int dramaId;
  const DramaDetailPage({super.key, required this.dramaId});

  @override
  State<DramaDetailPage> createState() => _DramaDetailPageState();
}

class _DramaDetailPageState extends State<DramaDetailPage> {
  Drama? _drama;
  List<Episode> _episodes = [];
  bool _favorite = false;
  bool _loading = true;
  String? _error;
  final Set<int> _unlocked = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DramaProvider>().refreshWallet();
    });
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final dp = context.read<DramaProvider>();
    try {
      final resp = await dp.dramaService.detail(widget.dramaId);
      if (!mounted) return;
      final raw = resp.data;
      if (raw is! Map || '${raw['code']}' != '10000') {
        throw Exception('加载失败');
      }
      final data = Map<String, dynamic>.from(raw['data'] as Map);
      final eps = (data['episodes'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Episode.fromJson(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => a.episodeNo.compareTo(b.episodeNo));
      for (final ep in eps.where((e) => !e.isFree).take(12)) {
        final info = await dp.loadPlayInfo(ep.id);
        if (!mounted) return;
        if (info != null && !info.locked) {
          _unlocked.add(ep.id);
        }
      }
      if (!mounted) return;
      setState(() {
        _drama = Drama.fromJson(Map<String, dynamic>.from(data['drama'] as Map));
        _episodes = eps;
        _favorite = data['favorite'] == true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  bool _needsUnlock(Episode ep) => !ep.isFree && !_unlocked.contains(ep.id);

  Future<void> _playEpisode(Episode ep) async {
    final dp = context.read<DramaProvider>();
    await dp.refreshWallet();
    final info = await dp.loadPlayInfo(ep.id);
    if (!mounted || info == null) return;
    if (info.locked) {
      final ok = await showUnlockSheet(
        context,
        episodeId: ep.id,
        unlockPrice: ep.unlockPrice,
        bundlePrice: _drama?.bundlePrice,
        dramaId: _drama?.id,
      );
      if (ok != true || !mounted) return;
      await dp.refreshWallet();
      setState(() => _unlocked.add(ep.id));
    } else if (!ep.isFree) {
      setState(() => _unlocked.add(ep.id));
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EpisodePlayPage(drama: _drama!, episode: ep),
      ),
    );
    // 返回后刷新锁状态
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final bal = context.watch<DramaProvider>().wallet?.balance;
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: _kPrimary)));
    }
    if (_error != null || _drama == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_error ?? '未找到')),
      );
    }
    final d = _drama!;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F1A),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: const Color(0xFF0B0F1A),
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                d.title,
                style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w700),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  d.coverUrl.isEmpty
                      ? Container(color: Colors.grey.shade800)
                      : Image.network(d.coverUrl, fit: BoxFit.cover),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xCC0B0F1A)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (bal != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      '$bal 币',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              IconButton(
                icon: Icon(_favorite ? Icons.bookmark : Icons.bookmark_border, color: Colors.white),
                onPressed: () async {
                  await context.read<DramaProvider>().toggleFavorite(d.id, currentlyFav: _favorite);
                  setState(() => _favorite = !_favorite);
                },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${d.category} · 共${_episodes.isEmpty ? d.totalEpisodes : _episodes.length}集 · 前${d.freeEpisodeCount}集免费',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 13),
                  ),
                  if (d.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      d.description,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.82), height: 1.4),
                    ),
                  ],
                  const SizedBox(height: 18),
                  const Text('选集', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final ep = _episodes[i];
                  final locked = _needsUnlock(ep);
                  return Material(
                    color: _kCell,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () => _playEpisode(ep),
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        children: [
                          Center(
                            child: Text(
                              '${ep.episodeNo}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: locked ? 0.55 : 0.92),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (locked)
                            Positioned(
                              right: 4,
                              bottom: 4,
                              child: Icon(Icons.lock_rounded, size: 12, color: Colors.white.withValues(alpha: 0.45)),
                            ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: _episodes.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
