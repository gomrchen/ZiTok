import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../services/comment_service.dart';

const _kSheetBg = Color(0xFF141820);
const _kInputBg = Color(0xFF1E2530);
const _kPrimary = Color(0xFF2ED3BE);

Future<void> showEpisodeCommentsSheet(BuildContext context, {required int episodeId}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) {
      final h = MediaQuery.sizeOf(ctx).height * 0.58;
      return AnimatedPadding(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SizedBox(
          height: h,
          width: MediaQuery.sizeOf(ctx).width,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: _kSheetBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, -4)),
              ],
            ),
            child: _EpisodeCommentsBody(episodeId: episodeId),
          ),
        ),
      );
    },
  );
}

class _EpisodeCommentsBody extends StatefulWidget {
  final int episodeId;
  const _EpisodeCommentsBody({required this.episodeId});

  @override
  State<_EpisodeCommentsBody> createState() => _EpisodeCommentsBodyState();
}

class _EpisodeCommentsBodyState extends State<_EpisodeCommentsBody> {
  late final CommentService _api = CommentService(AppBootstrap.apiClient.dio);
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  List<Map<String, dynamic>> _list = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await _api.episodeCommentList(episodeId: widget.episodeId);
      final raw = resp.data;
      if (raw is! Map || '${raw['code']}' != '10000') {
        throw Exception(raw is Map ? raw['message'] : '加载失败');
      }
      final data = raw['data'];
      final list = data is Map ? (data['list'] as List? ?? []) : (data as List? ?? []);
      if (!mounted) return;
      setState(() {
        _list = list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
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

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final resp = await _api.addEpisodeComment(episodeId: widget.episodeId, content: text);
      final raw = resp.data;
      if (raw is! Map || '${raw['code']}' != '10000') {
        throw Exception(raw is Map ? raw['message'] : '发送失败');
      }
      _ctrl.clear();
      _focus.unfocus();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('发送失败: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
          child: Row(
            children: [
              const Text(
                '评论',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 8),
              if (!_loading)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _kPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${_list.length}',
                    style: const TextStyle(
                      color: _kPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.of(context).maybePop(),
                icon: Icon(Icons.close, size: 20, color: Colors.white.withValues(alpha: 0.55)),
              ),
            ],
          ),
        ),
        Expanded(child: _buildBody()),
        _Composer(
          controller: _ctrl,
          focusNode: _focus,
          sending: _sending,
          onSend: _send,
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2.4));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _load,
              style: TextButton.styleFrom(foregroundColor: _kPrimary),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (_list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
              child: Icon(Icons.chat_bubble_outline_rounded, size: 28, color: Colors.white.withValues(alpha: 0.35)),
            ),
            const SizedBox(height: 14),
            Text('还没有评论', style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('来说一句吧', style: TextStyle(color: Colors.white.withValues(alpha: 0.38), fontSize: 12)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: _kPrimary,
      backgroundColor: _kInputBg,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        itemCount: _list.length,
        itemBuilder: (_, i) => _CommentTile(data: _list[i]),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _CommentTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final content = '${data['content'] ?? data['Content'] ?? ''}';
    final uid = data['userId'] ?? data['user_id'] ?? 0;
    final id = uid is int ? uid : int.tryParse('$uid') ?? 0;
    final color = _avatarColor(id);
    final name = id > 0 ? '用户$id' : '访客';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.85),
            child: Text(
              id > 0 ? '$id' : '?',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    height: 1.35,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Color _avatarColor(int id) {
    const palette = <Color>[
      Color(0xFF2ED3BE),
      Color(0xFF60A5FA),
      Color(0xFFF472B6),
      Color(0xFFFBBF24),
      Color(0xFFA78BFA),
      Color(0xFF34D399),
    ];
    return palette[id.abs() % palette.length];
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(14, 10, 14, 10 + math.max(0, MediaQuery.paddingOf(context).bottom - 4)),
      decoration: BoxDecoration(
        color: _kSheetBg,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: _kInputBg,
                borderRadius: BorderRadius.circular(22),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                style: const TextStyle(color: Colors.white, fontSize: 14.5),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: '友善发言…',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.32), fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: sending ? _kPrimary.withValues(alpha: 0.45) : _kPrimary,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              onTap: sending ? null : onSend,
              borderRadius: BorderRadius.circular(22),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.arrow_upward_rounded, color: Color(0xFF0B0F1A), size: 22),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
