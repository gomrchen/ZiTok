import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n_ext.dart';
import '../home/shell_surface.dart';

/// 验证码倒计时（注册 / 忘记密码共用）
mixin AuthCodeCountdown<T extends StatefulWidget> on State<T> {
  Timer? _authCodeTimer;
  int authCodeCountdown = 0;
  bool authCodeSending = false;

  @override
  void dispose() {
    _authCodeTimer?.cancel();
    super.dispose();
  }

  void startAuthCodeCountdown({int seconds = 60}) {
    _authCodeTimer?.cancel();
    setState(() {
      authCodeCountdown = seconds;
      authCodeSending = false;
    });
    _authCodeTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (authCodeCountdown <= 1) {
        t.cancel();
        setState(() => authCodeCountdown = 0);
      } else {
        setState(() => authCodeCountdown -= 1);
      }
    });
  }
}

/// 鉴权页统一视觉：纸色画布 + 短剧品牌氛围 + 珊瑚主 CTA
class AuthChrome {
  static const brand = 'ZiTok';
  static const brandSuffix = '短剧';
  static const tagline = '竖屏连播 · 一口气看完';
  static const demoHint = '演示账号 zitok / demo1234';

  static SystemUiOverlayStyle systemUiOf(BuildContext context) =>
      ShellSurface.systemUiOf(context);

  static InputDecoration fieldDecoration({
    required BuildContext context,
    required String label,
    String? hint,
    Widget? suffix,
  }) {
    final ink = ShellSurface.inkOf(context);
    final dark = ShellSurface.isDark(context);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      filled: true,
      fillColor: dark
          ? ShellSurface.cardOf(context)
          : Colors.white.withValues(alpha: 0.72),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: TextStyle(
        color: ink.withValues(alpha: 0.55),
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      hintStyle: TextStyle(
        color: ink.withValues(alpha: 0.28),
        fontSize: 14,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: ink.withValues(alpha: dark ? 0.16 : 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: ShellSurface.coral, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE24B4A)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE24B4A), width: 1.4),
      ),
    );
  }
}

class AuthScaffold extends StatelessWidget {
  final Widget child;
  final bool showBack;
  final VoidCallback? onBack;

  const AuthScaffold({
    super.key,
    required this.child,
    this.showBack = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final ink = ShellSurface.inkOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AuthChrome.systemUiOf(context),
      child: Scaffold(
        backgroundColor: ShellSurface.canvasOf(context),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const _AuthAtmosphere(),
            SafeArea(
              child: Column(
                children: [
                  if (showBack)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                        color: ink,
                      ),
                    ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthBrandHeader extends StatelessWidget {
  final String? eyebrow;
  final String title;
  final String subtitle;
  final String? tip;

  const AuthBrandHeader({
    super.key,
    this.eyebrow,
    required this.title,
    required this.subtitle,
    this.tip,
  });

  @override
  Widget build(BuildContext context) {
    final ink = ShellSurface.inkOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFF8A6B), ShellSurface.coral],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              eyebrow ?? '${AuthChrome.brand} ${AuthChrome.brandSuffix}',
              style: TextStyle(
                color: ink,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: TextStyle(
            color: ink,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            height: 1.1,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: TextStyle(
            color: ink.withValues(alpha: 0.52),
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ),
        if (tip != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: ShellSurface.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              tip!,
              style: TextStyle(
                color: ShellSurface.isDark(context)
                    ? ShellSurface.accent
                    : const Color(0xFF0F8F82),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class AuthErrorBanner extends StatelessWidget {
  final String message;
  const AuthErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEDEA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x33E24B4A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFE24B4A)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFB42318),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: ShellSurface.coral,
          foregroundColor: Colors.white,
          disabledBackgroundColor: ShellSurface.coral.withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
              )
            : Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.2)),
      ),
    );
  }
}

class AuthSecondaryLink extends StatelessWidget {
  final String prefix;
  final String action;
  final VoidCallback onTap;

  const AuthSecondaryLink({
    super.key,
    required this.prefix,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ink = ShellSurface.inkOf(context);
    final dark = ShellSurface.isDark(context);
    return Material(
      color: dark
          ? ShellSurface.cardOf(context)
          : Colors.white.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ink.withValues(alpha: dark ? 0.16 : 0.08)),
          ),
          child: RichText(
            text: TextSpan(
              text: prefix,
              style: TextStyle(
                color: ink.withValues(alpha: 0.55),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              children: [
                TextSpan(
                  text: action,
                  style: const TextStyle(
                    color: ShellSurface.coral,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuthCodeButton extends StatelessWidget {
  final int countdown;
  final bool busy;
  final VoidCallback? onPressed;

  const AuthCodeButton({
    super.key,
    required this.countdown,
    required this.busy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final waiting = countdown > 0;
    final ink = ShellSurface.inkOf(context);
    return SizedBox(
      width: 118,
      height: 52,
      child: OutlinedButton(
        onPressed: (busy || waiting) ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: BorderSide(color: ink.withValues(alpha: 0.12)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(
          waiting ? '${countdown}s' : context.l10n.registerGetCode,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
            color: waiting ? ink.withValues(alpha: 0.4) : ink,
          ),
        ),
      ),
    );
  }
}

class _AuthAtmosphere extends StatelessWidget {
  const _AuthAtmosphere();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    ShellSurface.coral.withValues(alpha: 0.18),
                    ShellSurface.coral.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -70,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    ShellSurface.accent.withValues(alpha: 0.16),
                    ShellSurface.accent.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: _FilmFramePainter()),
          ),
        ],
      ),
    );
  }
}

class _FilmFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ShellSurface.ink.withValues(alpha: 0.035)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()
      ..moveTo(size.width * 0.12, size.height * 0.18)
      ..quadraticBezierTo(size.width * 0.5, size.height * 0.08, size.width * 0.88, size.height * 0.22);
    canvas.drawPath(path, paint);

    final soft = Paint()
      ..color = ShellSurface.ink.withValues(alpha: 0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(size.width * 1.05, size.height * 0.72), radius: size.width * 0.55),
      math.pi * 0.7,
      math.pi * 0.9,
      false,
      soft,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
