import 'package:flutter/material.dart';

import 'player_handle.dart';

class SubtitleCue {
  final Duration start;
  final Duration end;
  final String text;
  const SubtitleCue({required this.start, required this.end, required this.text});
}

/// 极简 WebVTT / SRT 解析（外挂字幕）
List<SubtitleCue> parseSubtitleTrack(String raw) {
  final text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
  if (text.isEmpty) return const [];
  final cues = <SubtitleCue>[];

  if (text.startsWith('WEBVTT') || text.contains('-->')) {
    final blocks = text.split(RegExp(r'\n\s*\n'));
    for (final b in blocks) {
      final lines = b.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (lines.isEmpty) continue;
      final timeIdx = lines.indexWhere((e) => e.contains('-->'));
      if (timeIdx < 0) continue;
      final timeLine = lines[timeIdx];
      final parts = timeLine.split('-->');
      if (parts.length < 2) continue;
      final start = _parseTs(parts[0].trim());
      final end = _parseTs(parts[1].trim().split(RegExp(r'\s+')).first);
      final body = lines.skip(timeIdx + 1).join('\n').trim();
      if (body.isEmpty) continue;
      cues.add(SubtitleCue(start: start, end: end, text: body));
    }
  }
  return cues;
}

Duration _parseTs(String s) {
  final clean = s.replaceAll(',', '.');
  final bits = clean.split(':');
  if (bits.length == 3) {
    final h = int.tryParse(bits[0]) ?? 0;
    final m = int.tryParse(bits[1]) ?? 0;
    final sec = double.tryParse(bits[2]) ?? 0;
    return Duration(milliseconds: ((h * 3600 + m * 60 + sec) * 1000).round());
  }
  if (bits.length == 2) {
    final m = int.tryParse(bits[0]) ?? 0;
    final sec = double.tryParse(bits[1]) ?? 0;
    return Duration(milliseconds: ((m * 60 + sec) * 1000).round());
  }
  return Duration.zero;
}

class PlayerSubtitleLayer extends StatefulWidget {
  final PlayHandle? handle;
  final List<SubtitleCue> cues;
  final bool enabled;

  const PlayerSubtitleLayer({
    super.key,
    required this.handle,
    required this.cues,
    this.enabled = true,
  });

  @override
  State<PlayerSubtitleLayer> createState() => _PlayerSubtitleLayerState();
}

class _PlayerSubtitleLayerState extends State<PlayerSubtitleLayer> {
  @override
  void initState() {
    super.initState();
    widget.handle?.addListener(_onTick);
  }

  @override
  void didUpdateWidget(covariant PlayerSubtitleLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.handle != widget.handle) {
      oldWidget.handle?.removeListener(_onTick);
      widget.handle?.addListener(_onTick);
    }
  }

  @override
  void dispose() {
    widget.handle?.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final handle = widget.handle;
    if (!widget.enabled ||
        handle == null ||
        !handle.isInitialized ||
        widget.cues.isEmpty) {
      return const SizedBox.shrink();
    }
    final pos = handle.position;
    SubtitleCue? hit;
    for (final c in widget.cues) {
      if (pos >= c.start && pos <= c.end) {
        hit = c;
        break;
      }
    }
    if (hit == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(left: 24, right: 24, bottom: 120),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                hit.text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
