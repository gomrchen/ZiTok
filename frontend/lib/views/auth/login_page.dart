import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n_ext.dart';
import '../../providers/auth_provider.dart';
import '../home/shell_surface.dart';
import 'auth_chrome.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameCtrl = TextEditingController(text: 'zitok');
  final _pwdCtrl = TextEditingController(text: 'demo1234');
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthProvider>().clearError();
    });
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthProvider auth) async {
    final u = _usernameCtrl.text.trim();
    final p = _pwdCtrl.text;
    if (u.isEmpty || p.isEmpty) {
      auth.setLocalError(context.l10n.loginNeedCredentials);
      return;
    }
    await auth.login(u, p);
    if (!mounted) return;
    if (auth.isAuthenticated) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final l10n = context.l10n;
    return AuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuthBrandHeader(
            title: l10n.loginWelcomeBack,
            subtitle: l10n.tagline,
            tip: l10n.demoHint,
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _usernameCtrl,
            textInputAction: TextInputAction.next,
            onChanged: (_) => auth.clearError(),
            decoration: AuthChrome.fieldDecoration(
              context: context,
              label: l10n.loginUsername,
              hint: l10n.loginUsernameHint,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _pwdCtrl,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onChanged: (_) => auth.clearError(),
            onSubmitted: (_) => _submit(auth),
            decoration: AuthChrome.fieldDecoration(
              context: context,
              label: l10n.loginPassword,
              hint: l10n.loginPasswordHint,
              suffix: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: ShellSurface.ink.withValues(alpha: 0.45),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.go('/auth/forgot-password'),
              child: Text(
                l10n.loginForgot,
                style: TextStyle(
                  color: ShellSurface.ink.withValues(alpha: 0.48),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          if (auth.error != null) ...[
            AuthErrorBanner(message: auth.error!),
            const SizedBox(height: 14),
          ],
          AuthPrimaryButton(
            label: l10n.loginAction,
            loading: auth.loading,
            onPressed: () => _submit(auth),
          ),
          const SizedBox(height: 12),
          AuthSecondaryLink(
            prefix: l10n.loginNoAccount,
            action: l10n.loginRegisterNow,
            onTap: () => context.go('/auth/register'),
          ),
        ],
      ),
    );
  }
}
