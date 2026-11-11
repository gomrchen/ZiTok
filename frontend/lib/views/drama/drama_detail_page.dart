import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:zitok/l10n/app_localizations.dart';

import '../../models/drama_models.dart';
import '../../providers/drama_provider.dart';
import '../../widgets/glass_nav.dart';
import '../home/shell_surface.dart';
import 'drama_detail_loader.dart';
import 'episode_label.dart';
import 'episode_play_page.dart';
import 'media_url.dart';
import 'player_overlay.dart';
import 'player_session.dart';
import 'unlock_sheet.dart';

const _kBg = Color(0xFF0A0C12);
const _kCell = Color(0xFF1A2030);
const _kCellHi = Color(0xFF242C3E);

/// 短剧详情：影院感封面 + 清晰信息层 + 精品选集 + 底部立即播放
class DramaDetailPage extends StatefulWidget {
  final int dramaId;
  /// 分享/深链带入的集 ID，加载完成后自动进入播放
  final int? initialEpisodeId;
  const DramaDetailPage({super.key, required this.dramaId, this.initialEpisodeId});

  @override
  State<DramaDetailPage> createState() => _DramaDetailPageState();
}

class _DramaDetailPageState extends State<DramaDetailPage> {
  Drama? _drama;
  List<Episode> _episodes = [];
  bool _favorite = false;
  bool _loading = true;
  bool _descExpanded = false;
  bool _autoPlayConsumed = false;
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
      final bundle = await loadDramaDetailBundle(
        dp,
        widget.dramaId,
        probeUnlocked: true,
        parseDrama: true,
      );
      if (!mounted) return;
      setState(() {
        _drama = bundle.drama;
        _episodes = bundle.episodes;
        _unlocked
          ..clear()
          ..addAll(bundle.unlocked);
        _favorite = bundle.favorite;
        _loading = false;
      });
      _maybeAutoPlay();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = playerFriendlyError(e, fallback: '加载失败，请稍后重试');
        _loading = false;
      });
    }
  }

  bool _needsUnlock(Episode ep) => !ep.isFree && !_unlocked.contains(ep.id);

  void _maybeAutoPlay() {
    if (_autoPlayConsumed) return;
    final id = widget.initialEpisodeId;
    if (id == null || id <= 0 || _episodes.isEmpty) return;
    Episode? ep;
    for (final e in _episodes) {
      if (e.id == id) {
        ep = e;
        break;
      }
    }
    if (ep == null) return;
    _autoPlayConsumed = true;
    final target = ep;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_playEpisode(target));
    });
  }

  Episode? get _playTarget {
    if (_episodes.isEmpty) return null;
    // 深链指定集
    final initial = widget.initialEpisodeId;
    if (initial != null && initial > 0) {
      for (final e in _episodes) {
        if (e.id == initial) return e;
      }
    }
    // 在追进度集
    final cont = context.read<DramaProvider>().continueList;
    for (final c in cont) {
      if (c.drama?.id != widget.dramaId) continue;
      final eid = c.resumeEpisodeId;
      if (eid <= 0) continue;
      for (final e in _episodes) {
        if (e.id == eid) return e;
      }
      // 仅有集号时兜底
      for (final e in _episodes) {
        if (e.episodeNo == c.episodeNo) return e;
      }
    }
    final free = _episodes.where((e) => e.isFree || _unlocked.contains(e.id));
    return free.isNotEmpty ? free.first : _episodes.first;
  }

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
    if (mounted) _load();
  }

  Future<void> _toggleFavorite() async {
    final d = _drama;
    if (d == null) return;
    final was = _favorite;
    setState(() => _favorite = !was);
    final next = await toggleDramaFavorite(
      dp: context.read<DramaProvider>(),
      dramaId: d.id,
      currentlyFav: was,
    );
    if (!mounted) return;
    setState(() => _favorite = next ?? was);
  }

  @override
  Widget build(BuildContext context) {
    final bal = context.watch<DramaProvider>().wallet?.balance;
    if (_loading) {
      return const Scaffold(
        backgroundColor: _kBg,
        body: Center(child: CircularProgressIndicator(color: kPlayerAccent)),
      );
    }
    if (_error != null || _drama == null) {
      return Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(
          backgroundColor: _kBg,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Center(
              child: GlassNavButton(
                tooltip: '返回',
                icon: Icons.arrow_back_ios_new_rounded,
                onPressed: () => ShellSurface.popOrHome(context),
              ),
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error ?? '未找到',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _load,
                style: FilledButton.styleFrom(backgroundColor: kPlayerPrimary),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    final d = _drama!;
    final l10n = AppLocalizations.of(context);
    final epCount = _episodes.isEmpty ? d.totalEpisodes : _episodes.length;
    final tags = dramaMetaTags(d, max: 5);
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 360,
                pinned: true,
                stretch: true,
                elevation: 0,
                scrolledUnderElevation: 0,
                backgroundColor: _kBg,
                leadingWidth: 56,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Center(
                    child: GlassNavButton(
                      tooltip: '返回',
                      icon: Icons.arrow_back_ios_new_rounded,
                      onPressed: () => ShellSurface.popOrHome(context),
                    ),
                  ),
                ),
                actions: [
                  if (bal != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Center(
                        child: GlassNavChip(
                          onPressed: () => context.push('/wallet'),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.monetization_on_rounded,
                                  size: 15, color: Color(0xFFFFC857)),
                              const SizedBox(width: 4),
                              Text(
                                '$bal',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Center(
                      child: GlassNavButton(
                        icon: _favorite ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        iconColor: _favorite ? kPlayerAccent : Colors.white,
                        onPressed: _toggleFavorite,
                      ),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [
                    StretchMode.zoomBackground,
                    StretchMode.blurBackground,
                  ],
                  background: _HeroCover(url: d.coverUrl),
                ),
              ),
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -28),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (d.category.trim().isNotEmpty)
                              _MetaBadge(
                                label: d.category.trim(),
                                filled: true,
                              ),
                            _MetaBadge(label: '共$epCount集'),
                            _MetaBadge(
                              label: '前${d.freeEpisodeCount}集免费',
                              accent: true,
                            ),
                            if (d.playCount > 0)
                              _MetaBadge(label: _formatCount(d.playCount)),
                          ],
                        ),
                        if (tags.where((t) => t != d.category.trim()).isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final t in tags.where((t) => t != d.category.trim()))
                                _TagPill(label: t),
                            ],
                          ),
                        ],
                        if (d.description.trim().isNotEmpty) ...[
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () => setState(() => _descExpanded = !_descExpanded),
                            behavior: HitTestBehavior.opaque,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.description.trim(),
                                  maxLines: _descExpanded ? 20 : 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.78),
                                    fontSize: 14,
                                    height: 1.55,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _descExpanded ? l10n.playerCollapse : l10n.playerExpand,
                                  style: const TextStyle(
                                    color: kPlayerAccent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),
                        Row(
                          children: [
                            Container(
                              width: 3,
                              height: 16,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(99),
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Color(0xFFFF8A6B), kPlayerPrimary],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '选集',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '更新至 $epCount 集',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 108 + bottomPad),
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
                      final free = ep.isFree;
                      return _EpisodeCell(
                        episodeNo: ep.episodeNo,
                        locked: locked,
                        free: free,
                        onTap: () => _playEpisode(ep),
                      );
                    },
                    childCount: _episodes.length,
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomPlayBar(
              bottomPad: bottomPad,
              episodeNo: _playTarget?.episodeNo ?? 1,
              onPlay: () {
                final ep = _playTarget;
                if (ep != null) _playEpisode(ep);
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _formatCount(int n) {
    if (n >= 10000) {
      final v = n / 10000;
      return '${v.toStringAsFixed(v >= 10 ? 0 : 1)}万播放';
    }
    return '$n播放';
  }
}

class _HeroCover extends StatelessWidget {
  final String url;

  const _HeroCover({required this.url});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (url.isEmpty)
          const ColoredBox(color: Color(0xFF1A2030))
        else
          Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF1A2030)),
          ),
        // 顶部压暗，保证玻璃按钮可读
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.55),
                Colors.transparent,
                Colors.transparent,
              ],
              stops: const [0.0, 0.28, 0.5],
            ),
          ),
        ),
        // 底部柔化融进背景
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Color(0x660A0C12),
                Color(0xE60A0C12),
                _kBg,
              ],
              stops: [0.35, 0.62, 0.85, 1.0],
            ),
          ),
        ),
        // 轻微暗角
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.05,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.28),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetaBadge extends StatelessWidget {
  final String label;
  final bool filled;
  final bool accent;

  const _MetaBadge({
    required this.label,
    this.filled = false,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    if (filled) {
      bg = kPlayerPrimary.withValues(alpha: 0.18);
      fg = const Color(0xFFFFB39E);
    } else if (accent) {
      bg = kPlayerAccent.withValues(alpha: 0.14);
      fg = kPlayerAccent;
    } else {
      bg = Colors.white.withValues(alpha: 0.08);
      fg = Colors.white.withValues(alpha: 0.78);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  final String label;
  const _TagPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.65),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _EpisodeCell extends StatelessWidget {
  final int episodeNo;
  final bool locked;
  final bool free;
  final VoidCallback onTap;

  const _EpisodeCell({
    required this.episodeNo,
    required this.locked,
    required this.free,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: locked ? _kCell : _kCellHi,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: kPlayerPrimary.withValues(alpha: 0.18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: free && !locked
                  ? kPlayerAccent.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.06),
            ),
            gradient: locked
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                  ),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  '$episodeNo',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: locked ? 0.42 : 0.95),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              if (locked)
                Positioned(
                  right: 5,
                  bottom: 5,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      size: 10,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                )
              else if (free)
                Positioned(
                  left: 5,
                  top: 5,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: kPlayerAccent,
                      shape: BoxShape.circle,
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

class _BottomPlayBar extends StatelessWidget {
  final double bottomPad;
  final int episodeNo;
  final VoidCallback onPlay;

  const _BottomPlayBar({
    required this.bottomPad,
    required this.episodeNo,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomPad),
          decoration: BoxDecoration(
            color: const Color(0xE60A0C12),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
            ),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF8A6B), kPlayerPrimary],
                ),
                boxShadow: [
                  BoxShadow(
                    color: kPlayerPrimary.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onPlay,
                  borderRadius: BorderRadius.circular(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                      const SizedBox(width: 4),
                      Text(
                        '立即播放 第$episodeNo集',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
