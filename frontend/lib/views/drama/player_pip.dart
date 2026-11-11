import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/drama_models.dart';
import 'player_handle.dart';

typedef PipEpisodePageBuilder = Widget Function(Drama drama, Episode episode);

/// 应用内小窗（非系统 PiP）。可离页续播：打开后接管 PlayHandle，关闭时释放。
class PlayerPipController {
  static OverlayEntry? _entry;
  static Object? _ownerId;
  static VoidCallback? _onClosed;
  static PlayHandle? _handle;
  static Drama? _drama;
  static Episode? _episode;
  static NavigatorState? _nav;
  static final ValueNotifier<bool> isOpenListenable = ValueNotifier(false);
  static bool _tipShown = false;

  /// 由剧集页注册，避免循环 import
  static PipEpisodePageBuilder? episodePageBuilder;

  static bool get isOpen => _entry != null;
  static Object? get ownerId => _ownerId;
  static PlayHandle? get handle => _handle;

  static bool owns(Object ownerId) => isOpen && _ownerId == ownerId;

  static void close({bool disposeHandle = true}) {
    if (_entry == null && _handle == null) return;
    _entry?.remove();
    _entry = null;
    _ownerId = null;
    isOpenListenable.value = false;
    final cb = _onClosed;
    _onClosed = null;
    final h = _handle;
    _handle = null;
    _drama = null;
    _episode = null;
    _nav = null;
    if (disposeHandle) {
      h?.dispose();
    }
    cb?.call();
  }

  static void closeIfOwner(Object ownerId) {
    if (_ownerId == ownerId) close();
  }

  static PlayHandle? takeHandleForRestore() {
    final h = _handle;
    _handle = null;
    return h;
  }

  static void open(
    BuildContext context, {
    required PlayHandle handle,
    required Drama drama,
    required Episode episode,
    Object? ownerId,
    VoidCallback? onClosed,
    bool popCurrentRoute = true,
  }) {
    close(disposeHandle: true);
    _ownerId = ownerId ?? episode.id;
    _onClosed = onClosed;
    _handle = handle;
    _drama = drama;
    _episode = episode;
    _nav = Navigator.of(context, rootNavigator: true);

    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _PipBubble(
        handle: handle,
        title: '${drama.title} · 第${episode.episodeNo}集',
        onClose: () => close(disposeHandle: true),
        onExpand: _expand,
      ),
    );
    _entry = entry;
    isOpenListenable.value = true;
    overlay.insert(entry);

    if (!_tipShown) {
      _tipShown = true;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('已进入小窗，可继续浏览其它页面'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 1600),
        ),
      );
    }

    if (popCurrentRoute && _nav!.canPop()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final nav = _nav;
        if (nav != null && nav.canPop()) nav.pop();
      });
    }
  }

  static void _expand() {
    final drama = _drama;
    final episode = _episode;
    final nav = _nav;
    final builder = episodePageBuilder;
    final handle = takeHandleForRestore();
    _entry?.remove();
    _entry = null;
    _ownerId = null;
    isOpenListenable.value = false;
    _onClosed = null;
    _drama = null;
    _episode = null;
    _nav = null;
    if (drama == null || episode == null || nav == null || builder == null) {
      handle?.dispose();
      return;
    }
    _pendingRestore = _PipRestore(drama: drama, episode: episode, handle: handle);
    nav.push(MaterialPageRoute(builder: (_) => builder(drama, episode)));
  }

  static _PipRestore? _pendingRestore;

  static PlayHandle? claimPendingRestore({required int episodeId}) {
    final p = _pendingRestore;
    if (p == null || p.episode.id != episodeId) return null;
    _pendingRestore = null;
    return p.handle;
  }
}

class _PipRestore {
  final Drama drama;
  final Episode episode;
  final PlayHandle? handle;
  _PipRestore({required this.drama, required this.episode, required this.handle});
}

class _PipBubble extends StatefulWidget {
  final PlayHandle handle;
  final String title;
  final VoidCallback onClose;
  final VoidCallback onExpand;

  const _PipBubble({
    required this.handle,
    required this.title,
    required this.onClose,
    required this.onExpand,
  });

  @override
  State<_PipBubble> createState() => _PipBubbleState();
}

class _PipBubbleState extends State<_PipBubble> {
  static const _kX = 'zitok_pip_x';
  static const _kY = 'zitok_pip_y';
  static Offset _savedPos = const Offset(16, 120);
  late Offset _pos;

  @override
  void initState() {
    super.initState();
    _pos = _savedPos;
    widget.handle.addListener(_onTick);
    unawaited(_restorePos());
  }

  Future<void> _restorePos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final x = prefs.getDouble(_kX);
      final y = prefs.getDouble(_kY);
      if (x == null || y == null || !mounted) return;
      setState(() {
        _pos = Offset(x, y);
        _savedPos = _pos;
      });
    } catch (_) {}
  }

  Future<void> _persistPos() async {
    _savedPos = _pos;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kX, _pos.dx);
      await prefs.setDouble(_kY, _pos.dy);
    } catch (_) {}
  }

  @override
  void dispose() {
    widget.handle.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  Future<void> _togglePlay() async {
    final c = widget.handle;
    if (!c.isInitialized) return;
    if (c.isPlaying) {
      await c.pause();
    } else {
      await c.play();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final w = size.width * 0.42;
    final h = w * 16 / 9;
    final playing = widget.handle.isPlaying;
    return Positioned(
      left: _pos.dx.clamp(8.0, size.width - w - 8),
      top: _pos.dy.clamp(48.0, size.height - h - 24),
      child: Material(
        elevation: 10,
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: w,
          height: h,
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                onPanUpdate: (d) => setState(() => _pos += d.delta),
                onPanEnd: (_) => unawaited(_persistPos()),
                onDoubleTap: widget.onExpand,
                onTap: _togglePlay,
                child: widget.handle.isInitialized
                    ? widget.handle.buildCover()
                    : const ColoredBox(color: Colors.black),
              ),
              Positioned(
                left: 8,
                right: 40,
                bottom: 8,
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(color: Color(0x99000000), blurRadius: 4)],
                  ),
                ),
              ),
              Positioned(
                left: 2,
                top: 2,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: playing ? '暂停' : '播放',
                  onPressed: _togglePlay,
                  icon: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              Positioned(
                right: 2,
                top: 2,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: '关闭',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                ),
              ),
              Positioned(
                right: 2,
                bottom: 2,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: '还原',
                  onPressed: widget.onExpand,
                  icon: const Icon(Icons.open_in_full_rounded, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
