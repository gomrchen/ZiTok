import 'package:flutter/material.dart';

import '../views/home/shell_surface.dart';

/// 短剧封面：网络图失败时回落占位，避免联调外网图床超时后整片死灰无反馈。
class DramaNetworkCover extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;

  const DramaNetworkCover({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: ShellSurface.isDark(context)
          ? const Color(0xFF1F2937)
          : const Color(0xFFD9D4CC),
    );
    if (url.isEmpty) return placeholder;
    return Image.network(
      url,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (_, __, ___) => placeholder,
    );
  }
}
