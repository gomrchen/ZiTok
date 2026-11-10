import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// 将视频按 cover 铺满父布局（裁切溢出），避免上下/左右黑边。
class CoverVideo extends StatelessWidget {
  final VideoPlayerController controller;

  const CoverVideo({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }
    final size = controller.value.size;
    if (size.width <= 0 || size.height <= 0) {
      return const ColoredBox(color: Colors.black);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        if (!maxW.isFinite || !maxH.isFinite || maxW <= 0 || maxH <= 0) {
          return const ColoredBox(color: Colors.black);
        }
        final scale = math.max(maxW / size.width, maxH / size.height);
        final w = size.width * scale;
        final h = size.height * scale;
        return ClipRect(
          child: ColoredBox(
            color: Colors.black,
            child: OverflowBox(
              alignment: Alignment.center,
              minWidth: w,
              minHeight: h,
              maxWidth: w,
              maxHeight: h,
              child: SizedBox(
                width: w,
                height: h,
                child: FittedBox(
                  fit: BoxFit.fill,
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: VideoPlayer(controller),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
