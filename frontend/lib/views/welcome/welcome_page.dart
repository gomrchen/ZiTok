import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/theme_tokens.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool _demoLoading = false;

  @override
  void initState() {
    super.initState();
    // Debug 构建欢迎页自动演示登录，便于模拟器联调冒烟
    if (kDebugMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final auth = context.read<AuthProvider>();
        if (auth.isAuthenticated) {
          context.go('/home');
          return;
        }
        await _enterDemo();
      });
    }
  }

  Future<void> _enterDemo() async {
    if (_demoLoading) return;
    setState(() => _demoLoading = true);
    try {
      await context.read<AuthProvider>().login('zitok', 'demo1234');
      if (!mounted) return;
      if (context.read<AuthProvider>().isAuthenticated) {
        context.go('/home');
      }
    } finally {
      if (mounted) setState(() => _demoLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            final circleRadius = w * 0.75;
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _WelcomeOrbitPainter(
                      accent: theme.colorScheme.secondary,
                      strokeColor: theme.colorScheme.secondary.withValues(alpha: 0.7),
                      radius: circleRadius,
                    ),
                  ),
                ),
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
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(Spacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: Spacing.xl),
                        Text(
                          'ZiTok 短剧',
                          style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary),
                        ),
                        const SizedBox(height: Spacing.sm),
                        Text('竖屏连播 · 热门短剧', style: theme.textTheme.bodySmall),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _demoLoading ? null : _enterDemo,
                            child: _demoLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('演示账号进入'),
                          ),
                        ),
                        const SizedBox(height: Spacing.md),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => context.go('/auth/login'),
                            child: const Text('账号登录'),
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

    final center = Offset(-radius * 0.35, size.height * 0.6);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _WelcomeOrbitPainter oldDelegate) {
    return oldDelegate.radius != radius || oldDelegate.strokeColor != strokeColor;
  }
}
