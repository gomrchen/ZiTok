import 'package:flutter/material.dart';

/// 数字格式化：处理大数据量显示
/// - 10000+ 显示为 "1万+"
/// - 100000+ 显示为 "10万+"
/// - 1000000+ 显示为 "100万+"
/// - 小于10000 显示原数字（带千分位）
String formatCount(int? count) {
  if (count == null) return '0';
  if (count >= 100000000) {
    return '${(count / 100000000).toStringAsFixed(1)}亿';
  }
  if (count >= 10000) {
    final wan = count / 10000;
    if (wan >= 10) {
      return '${wan.toInt()}万+';
    }
    return '${wan.toStringAsFixed(1)}万';
  }
  if (count >= 1000) {
    // 添加千分位分隔符
    return count.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }
  return '$count';
}

/// 紧凑格式化（用于小空间，如推荐页右侧栏）
String formatCountCompact(int? count) {
  if (count == null) return '0';
  if (count >= 100000000) {
    return '${(count / 100000000).toStringAsFixed(1)}亿';
  }
  if (count >= 10000) {
    return '${(count / 10000).toStringAsFixed(1)}万';
  }
  if (count >= 1000) {
    return '${(count / 1000).toStringAsFixed(1)}k';
  }
  return '$count';
}

/// 视频统计数据显示组件
/// 统一显示评论数和点赞数，支持深色模式
class VideoStats extends StatelessWidget {
  final int? commentCount;
  final int? likeCount;
  final bool isDark; // 是否使用深色模式（白色文字）
  final double iconSize;
  final TextStyle? textStyle;

  const VideoStats({
    super.key,
    this.commentCount,
    this.likeCount,
    this.isDark = false,
    this.iconSize = 14,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultStyle = theme.textTheme.bodySmall?.copyWith(
      color: isDark ? Colors.white70 : Colors.grey.shade600,
    );
    final style = textStyle ?? defaultStyle;
    final iconColor = isDark ? Colors.white70 : Colors.grey.shade600;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 评论数
        Icon(Icons.chat_bubble_outline, size: iconSize, color: iconColor),
        const SizedBox(width: 4),
        Text(formatCount(commentCount), style: style),
        const SizedBox(width: 16), // 两数据项间距 16px
        // 点赞数
        Icon(Icons.favorite_border, size: iconSize, color: iconColor),
        const SizedBox(width: 4),
        Text(formatCount(likeCount), style: style),
      ],
    );
  }
}

/// 视频统计数据显示组件（文字版）
/// 显示格式："X 评论 · Y 点赞"
class VideoStatsText extends StatelessWidget {
  final int? commentCount;
  final int? likeCount;
  final bool isDark;
  final TextStyle? textStyle;

  const VideoStatsText({
    super.key,
    this.commentCount,
    this.likeCount,
    this.isDark = false,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultStyle = theme.textTheme.bodySmall?.copyWith(
      color: isDark ? Colors.white70 : Colors.grey.shade600,
    );
    final style = textStyle ?? defaultStyle;

    return Text(
      '${formatCount(commentCount)} 评论 · ${formatCount(likeCount)} 点赞',
      style: style,
    );
  }
}

/// 视频封面占位图组件
/// 用于封面加载失败或无封面时的统一显示
class VideoCoverPlaceholder extends StatelessWidget {
  final double? width;
  final double? height;
  final double iconSize;
  final BorderRadius? borderRadius;

  const VideoCoverPlaceholder({
    super.key,
    this.width,
    this.height,
    this.iconSize = 40,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5), // 默认背景色 #F5F5F5
        borderRadius: borderRadius,
      ),
      child: Center(
        child: Icon(
          Icons.videocam_outlined,
          size: iconSize,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }
}

/// 带网络图片加载的封面组件
/// 加载失败时自动显示占位图
class VideoCover extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const VideoCover({
    super.key,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url == null || url.isEmpty) {
      return VideoCoverPlaceholder(
        width: width,
        height: height,
        borderRadius: borderRadius,
      );
    }

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: width,
            height: height,
            color: const Color(0xFFF5F5F5),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return VideoCoverPlaceholder(
            width: width,
            height: height,
            borderRadius: borderRadius,
          );
        },
      ),
    );
  }
}
