import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n_ext.dart';
import '../../providers/auth_provider.dart';
import '../auth/auth_chrome.dart';
import '../home/shell_surface.dart';

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
    // 已登录则进首页；未登录保留欢迎页（不强制自动登录）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<AuthProvider>().isAuthenticated) {
        context.go('/home');
      }
    });
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
    final auth = context.watch<AuthProvider>();
    final l10n = context.l10n;
    return AuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            l10n.brandName,
            style: TextStyle(
              color: ShellSurface.inkOf(context),
              fontSize: 48,
              fontWeight: FontWeight.w900,
              height: 1.0,
              letterSpacing: -1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.brandSuffix,
            style: TextStyle(
              color: ShellSurface.coral.withValues(alpha: 0.95),
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.tagline,
            style: TextStyle(
              color: ShellSurface.inkOf(context).withValues(alpha: 0.55),
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: ShellSurface.isDark(context)
                  ? ShellSurface.cardOf(context)
                  : Colors.white.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: ShellSurface.inkOf(context).withValues(alpha: 0.06),
              ),
            ),
            child: Text(
              l10n.demoHint,
              style: TextStyle(
                color: ShellSurface.inkOf(context).withValues(alpha: 0.62),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 48),
          if (auth.error != null && _demoLoading == false) ...[
            AuthErrorBanner(message: auth.error!),
            const SizedBox(height: 14),
          ],
          AuthPrimaryButton(
            label: l10n.welcomeDemoEnter,
            loading: _demoLoading || auth.loading,
            onPressed: _enterDemo,
          ),
          const SizedBox(height: 12),
          AuthSecondaryLink(
            prefix: '',
            action: l10n.welcomeAccountLogin,
            onTap: () => context.go('/auth/login'),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: () => context.go('/auth/register'),
              child: Text(
                l10n.welcomeRegister,
                style: TextStyle(
                  color: ShellSurface.inkOf(context).withValues(alpha: 0.5),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
