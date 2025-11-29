import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/theme_tokens.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            // 背景尺寸：根据屏幕宽高自适应
            final circleRadius = w * 0.75;
            return Stack(
              children: [
                // 背景圆弧
                Positioned.fill(
                  child: CustomPaint(
                    painter: _WelcomeOrbitPainter(
                      accent: theme.colorScheme.secondary,
                      strokeColor: theme.colorScheme.secondary.withValues(alpha: 0.7),
                      radius: circleRadius,
                    ),
                  ),
                ),
                // 动态小圆点（入场动画）
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: -40, end: 0),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, offset, child) {
                    return Positioned(
                      top: h * 0.22 + offset,
                      left: w * 0.28 + offset,
                      child: _Dot(color: theme.colorScheme.secondary, size: 18),
                    );
                  },
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 40, end: 0),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, offset, child) {
                    return Positioned(
                      top: h * 0.32 + offset,
                      right: w * 0.20 + offset,
                      child: _Dot(color: theme.colorScheme.primary, size: 22),
                    );
                  },
                ),
                // 内容
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(Spacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: Spacing.xl),
                        Text('知音', style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary)),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => context.go('/auth/login'),
                            child: const Text('开始体验'),
                          ),
                        ),
                        const SizedBox(height: Spacing.xl),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  final double size;
  const _Dot({required this.color, required this.size});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _WelcomeOrbitPainter extends CustomPainter {
  final Color accent;
  final Color strokeColor;
  final double radius;
  _WelcomeOrbitPainter({required this.accent, required this.strokeColor, required this.radius});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // 圆心在屏幕左侧外部，绘制大圆弧与截取的边缘效果
    final center = Offset(-radius * 0.35, size.height * 0.6);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _WelcomeOrbitPainter oldDelegate) {
    return oldDelegate.radius != radius || oldDelegate.strokeColor != strokeColor;
  }
}