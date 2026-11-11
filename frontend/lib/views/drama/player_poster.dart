import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 截取 [boundaryKey] 对应画面并生成打卡海报分享
Future<void> captureAndSharePoster(
  BuildContext context, {
  required GlobalKey boundaryKey,
  required String title,
  required String episodeLabel,
  String deepLink = '',
  bool ready = true,
}) async {
  if (!ready) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('画面未就绪，请播放后再打卡'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }
  try {
    final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw StateError('no boundary');
    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw StateError('encode fail');
    final frameBytes = byteData.buffer.asUint8List();

    final poster = await _composePoster(
      frameBytes: frameBytes,
      title: title,
      episodeLabel: episodeLabel,
    );

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/zitok_poster_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(poster);
    if (!context.mounted) return;

    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : const Rect.fromLTWH(0, 0, 1, 1);

    final link = deepLink.trim();
    final text = link.isEmpty
        ? '我在 ZiTok 追《$title》$episodeLabel'
        : '我在 ZiTok 追《$title》$episodeLabel\n$link';
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png', name: 'zitok_poster.png')],
        text: text,
        subject: title,
        sharePositionOrigin: origin,
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('截图打卡失败，请稍后重试'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

Future<Uint8List> _composePoster({
  required Uint8List frameBytes,
  required String title,
  required String episodeLabel,
}) async {
  const w = 720.0;
  const h = 1280.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, w, h));

  canvas.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFF0A0C12));

  final codec = await ui.instantiateImageCodec(frameBytes, targetWidth: 720);
  final frame = await codec.getNextFrame();
  final img = frame.image;
  final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
  const dst = Rect.fromLTWH(40, 160, 640, 640 * 16 / 9);
  canvas.drawImageRect(img, src, dst, Paint());

  final titlePainter = TextPainter(
    text: TextSpan(
      text: title,
      style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 2,
    ellipsis: '…',
  )..layout(maxWidth: 640);
  titlePainter.paint(canvas, const Offset(40, 48));

  final epPainter = TextPainter(
    text: TextSpan(
      text: episodeLabel,
      style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 22, fontWeight: FontWeight.w600),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: 640);
  epPainter.paint(canvas, Offset(40, 48 + titlePainter.height + 10));

  final brand = TextPainter(
    text: const TextSpan(
      text: 'ZiTok 短剧',
      style: TextStyle(color: Color(0xFFFF6B4A), fontSize: 28, fontWeight: FontWeight.w800),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  brand.paint(canvas, const Offset(40, h - 80));

  final picture = recorder.endRecording();
  final out = await picture.toImage(w.toInt(), h.toInt());
  final data = await out.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}
