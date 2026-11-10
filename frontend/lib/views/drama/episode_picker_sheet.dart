import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/drama_models.dart';
import '../../providers/drama_provider.dart';
import 'unlock_sheet.dart';

const _kBg = Color(0xFF141820);
const _kPrimary = Color(0xFF2ED3BE);
const _kCell = Color(0xFF232A36);

/// 红果风格选集面板：封面信息 + 分集宫格（锁 / 正在播高亮）
Future<Episode?> showEpisodePickerSheet(
  BuildContext context, {
  required Drama drama,
  required int currentEpisodeId,
}) {
  return showModalBottomSheet<Episode>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (ctx) {
      final h = MediaQuery.sizeOf(ctx).height * 0.62;
      return AnimatedPadding(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SizedBox(
          height: h,
          width: MediaQuery.sizeOf(ctx).width,
          child: Material(
            color: _kBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: _EpisodePickerBody(
              drama: drama,
              currentEpisodeId: currentEpisodeId,
            ),
          ),
        ),
      );
    },
  );
}

class _EpisodePickerBody extends StatefulWidget {
  final Drama drama;
  final int currentEpisodeId;

  const _EpisodePickerBody({
    required this.drama,
    required this.currentEpisodeId,
  });

  @override
  State<_EpisodePickerBody> createState() => _EpisodePickerBodyState();
}

class _EpisodePickerBodyState extends State<_EpisodePickerBody> {
  List<Episode> _episodes = [];
  final Set<int> _unlocked = {};
  bool _loading = true;
  String? _error;
  int _rangeIndex = 0;

  static const _rangeSize = 30;

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
      final dp = context.read<DramaProvider>();
      final resp = await dp.dramaService.detail(widget.drama.id);
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
        if (info != null && !info.locked) _unlocked.add(ep.id);
      }

      if (!mounted) return;
      final cur = eps.indexWhere((e) => e.id == widget.currentEpisodeId);
      setState(() {
        _episodes = eps;
        _loading = false;
        if (cur >= 0) _rangeIndex = cur ~/ _rangeSize;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  bool _isLocked(Episode ep) => !ep.isFree && !_unlocked.contains(ep.id);

  int get _rangeCount => _episodes.isEmpty ? 1 : ((_episodes.length - 1) ~/ _rangeSize) + 1;

  List<Episode> get _visible {
    final start = _rangeIndex * _rangeSize;
    final end = (start + _rangeSize).clamp(0, _episodes.length);
    if (start >= _episodes.length) return const [];
    return _episodes.sublist(start, end);
  }

  Future<void> _onSelect(Episode ep) async {
    final dp = context.read<DramaProvider>();
    if (_isLocked(ep)) {
      final ok = await showUnlockSheet(
        context,
        episodeId: ep.id,
        unlockPrice: ep.unlockPrice,
        bundlePrice: widget.drama.bundlePrice,
        dramaId: widget.drama.id,
      );
      if (ok != true || !mounted) return;
      await dp.refreshWallet();
      setState(() => _unlocked.add(ep.id));
    }
    if (!mounted) return;
    Navigator.of(context).pop(ep);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.drama;
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: d.coverUrl.isEmpty
                    ? Container(width: 52, height: 70, color: _kCell)
                    : Image.network(
                        d.coverUrl,
                        width: 52,
                        height: 70,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(width: 52, height: 70, color: _kCell),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _loading
                          ? '加载选集…'
                          : '更新至 ${_episodes.isEmpty ? d.totalEpisodes : _episodes.length} 集 · 前 ${d.freeEpisodeCount} 集免费',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                    ),
                    if (d.category.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        d.category,
                        style: TextStyle(color: _kPrimary.withValues(alpha: 0.9), fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.55), size: 20),
              ),
            ],
          ),
        ),
        if (!_loading && _rangeCount > 1)
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _rangeCount,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final start = i * _rangeSize + 1;
                final end = ((i + 1) * _rangeSize).clamp(1, _episodes.length);
                final selected = i == _rangeIndex;
                return ChoiceChip(
                  label: Text('$start-$end'),
                  selected: selected,
                  onSelected: (_) => setState(() => _rangeIndex = i),
                  selectedColor: _kPrimary.withValues(alpha: 0.25),
                  backgroundColor: _kCell,
                  labelStyle: TextStyle(
                    color: selected ? _kPrimary : Colors.white70,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  side: BorderSide(color: selected ? _kPrimary : Colors.transparent),
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),
        const SizedBox(height: 8),
        Expanded(child: _buildGrid()),
      ],
    );
  }

  Widget _buildGrid() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2.4));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.white70)),
            TextButton(onPressed: _load, child: const Text('重试', style: TextStyle(color: _kPrimary))),
          ],
        ),
      );
    }
    if (_episodes.isEmpty) {
      return Center(child: Text('暂无分集', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))));
    }
    final items = _visible;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final ep = items[i];
        final playing = ep.id == widget.currentEpisodeId;
        final locked = _isLocked(ep);
        return _EpisodeCell(
          no: ep.episodeNo,
          playing: playing,
          locked: locked,
          onTap: () => _onSelect(ep),
        );
      },
    );
  }
}

class _EpisodeCell extends StatelessWidget {
  final int no;
  final bool playing;
  final bool locked;
  final VoidCallback onTap;

  const _EpisodeCell({
    required this.no,
    required this.playing,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: playing ? _kPrimary.withValues(alpha: 0.18) : _kCell,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: playing ? _kPrimary : Colors.transparent,
              width: 1.4,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  '$no',
                  style: TextStyle(
                    color: playing ? _kPrimary : Colors.white.withValues(alpha: locked ? 0.55 : 0.92),
                    fontSize: 15,
                    fontWeight: playing ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              if (locked)
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Icon(Icons.lock_rounded, size: 12, color: Colors.white.withValues(alpha: 0.45)),
                ),
              if (playing)
                Positioned(
                  left: 5,
                  top: 5,
                  child: Icon(Icons.graphic_eq_rounded, size: 12, color: _kPrimary.withValues(alpha: 0.95)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
