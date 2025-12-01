import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/video_provider.dart';

/// 统一的带动画点赞按钮组件
///
/// 特性：
/// - 空心/实心状态切换
/// - 点赞时缩放动画
/// - 粒子爆裂效果
/// - 支持浅色/深色模式
class AnimatedLikeButton extends StatefulWidget {
  final String videoId;
  final int? likeCount;
  final bool showCount;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;
  final bool darkMode;

  const AnimatedLikeButton({
    super.key,
    required this.videoId,
    this.likeCount,
    this.showCount = true,
    this.size = 24,
    this.activeColor,
    this.inactiveColor,
    this.darkMode = false,
  });

  @override
  State<AnimatedLikeButton> createState() => _AnimatedLikeButtonState();
}

class _AnimatedLikeButtonState extends State<AnimatedLikeButton>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _burstController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _burstController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    final vp = context.read<VideoProvider>();
    final wasLiked = vp.isLiked(widget.videoId);

    // 触发动画
    _scaleController.forward(from: 0);
    if (!wasLiked) {
      _burstController.forward(from: 0);
    }

    // 调用切换点赞
    await vp.toggleLike(widget.videoId);
  }

  @override
  Widget build(BuildContext context) {
    final vp = context.watch<VideoProvider>();
    final isLiked = vp.isLiked(widget.videoId);
    final theme = Theme.of(context);

    final activeColor = widget.activeColor ?? Colors.red;
    final inactiveColor = widget.inactiveColor ??
        (widget.darkMode ? Colors.white : theme.colorScheme.onSurfaceVariant);

    // 获取实际点赞数
    int currentCount = widget.likeCount ?? 0;

    // 构建按钮核心
    final buttonCore = GestureDetector(
      onTap: _handleTap,
      child: SizedBox(
        width: widget.showCount ? widget.size + 16 : widget.size + 8,
        height: widget.showCount ? widget.size + 16 : widget.size + 8,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // 粒子效果（仅点赞时显示）
            AnimatedBuilder(
              animation: _burstController,
              builder: (context, child) {
                if (_burstController.value == 0) return const SizedBox();
                final t = _burstController.value;
                final radius = 16 * t;
                final opacity = (1 - t).clamp(0.0, 1.0);
                final c = activeColor.withValues(alpha: opacity);
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _buildParticle(Offset(0, -radius), c),
                    _buildParticle(Offset(0, radius), c),
                    _buildParticle(Offset(radius, 0), c),
                    _buildParticle(Offset(-radius, 0), c),
                    _buildParticle(Offset(radius * 0.7, -radius * 0.7), c),
                    _buildParticle(Offset(-radius * 0.7, -radius * 0.7), c),
                  ],
                );
              },
            ),
            // 圆形背景（深色模式下显示）
            if (widget.darkMode)
              Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x33000000),
                ),
              ),
            // 心形图标
            ScaleTransition(
              scale: _scaleAnimation,
              child: Icon(
                isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                size: widget.size,
                color: isLiked ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );

    // 如果不显示计数，直接返回按钮核心
    if (!widget.showCount) {
      return buttonCore;
    }

    // 显示计数时使用Column布局
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        buttonCore,
        const SizedBox(height: 4),
        Text(
          _formatCount(currentCount),
          style: TextStyle(
            fontSize: 12,
            color: widget.darkMode ? Colors.white : theme.textTheme.bodySmall?.color,
          ),
        ),
      ],
    );
  }

  Widget _buildParticle(Offset offset, Color color) {
    return Transform.translate(
      offset: offset,
      child: Icon(Icons.thumb_up, color: color, size: 8),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return '$count';
  }
}

/// 全屏视频用的点赞按钮（带背景和更大的点击区域）
class FullScreenLikeButton extends StatefulWidget {
  final String videoId;
  final int? likeCount;

  const FullScreenLikeButton({
    super.key,
    required this.videoId,
    this.likeCount,
  });

  @override
  State<FullScreenLikeButton> createState() => _FullScreenLikeButtonState();
}

class _FullScreenLikeButtonState extends State<FullScreenLikeButton>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _burstController;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _burstController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    final vp = context.read<VideoProvider>();
    final wasLiked = vp.isLiked(widget.videoId);

    _scaleController.forward(from: 0);
    if (!wasLiked) {
      _burstController.forward(from: 0);
    }

    await vp.toggleLike(widget.videoId);
  }

  @override
  Widget build(BuildContext context) {
    final vp = context.watch<VideoProvider>();
    final isLiked = vp.isLiked(widget.videoId);

    // 从视频列表中获取实际点赞数
    int count = widget.likeCount ?? 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _handleTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 粒子效果
                AnimatedBuilder(
                  animation: _burstController,
                  builder: (context, child) {
                    final t = _burstController.value;
                    if (t == 0) return const SizedBox();
                    final radius = 18 * t;
                    final opacity = (1 - t).clamp(0.0, 1.0);
                    final c = Colors.red.withValues(alpha: opacity);
                    return Stack(
                      children: [
                        _particle(Offset(0, -radius), c),
                        _particle(Offset(0, radius), c),
                        _particle(Offset(radius, 0), c),
                        _particle(Offset(-radius, 0), c),
                        _particle(Offset(radius * 0.7, -radius * 0.7), c),
                        _particle(Offset(-radius * 0.7, -radius * 0.7), c),
                      ],
                    );
                  },
                ),
                // 圆形背景
                Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x33000000),
                  ),
                ),
                // 心形图标
                ScaleTransition(
                  scale: Tween<double>(begin: 1.0, end: 1.25).animate(
                    CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
                  ),
                  child: Icon(
                    isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                    color: isLiked ? Colors.red : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _formatCount(count),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white),
        ),
      ],
    );
  }

  Widget _particle(Offset offset, Color color) {
    return Transform.translate(
      offset: offset,
      child: Icon(Icons.thumb_up, color: color, size: 10),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return '$count';
  }
}
