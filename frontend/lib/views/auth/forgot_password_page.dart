import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n_ext.dart';
import '../../providers/auth_provider.dart';
import '../../utils/error_handler.dart';
import '../../utils/validators.dart';
import '../home/shell_surface.dart';
import 'auth_chrome.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage>
    with AuthCodeCountdown {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _obscure = true;
  String? _localError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthProvider>().clearError();
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  void _setLocalError(String? msg) => setState(() => _localError = msg);

  Future<void> _sendCode() async {
    final l10n = context.l10n;
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _setLocalError(l10n.forgotNeedEmail);
      return;
    }
    if (!isValidEmail(email)) {
      _setLocalError(l10n.registerInvalidEmail);
      return;
    }
    setState(() {
      authCodeSending = true;
      _localError = null;
    });
    try {
      await context.read<AuthProvider>().sendVerificationCode(email);
      if (!mounted) return;
      startAuthCodeCountdown();
      ErrorHandler.showSuccess(context, context.l10n.codeSent);
    } catch (e) {
      if (!mounted) return;
      _setLocalError(
        ErrorHandler.getErrorMessage(e, defaultMessage: context.l10n.codeSendFailed),
      );
      setState(() => authCodeSending = false);
    }
  }

  Future<void> _reset() async {
    final l10n = context.l10n;
    final email = _emailCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    final pwd = _pwdCtrl.text;
    if (email.isEmpty) {
      _setLocalError(l10n.forgotNeedEmail);
      return;
    }
    if (!isValidEmail(email)) {
      _setLocalError(l10n.registerInvalidEmail);
      return;
    }
    if (code.isEmpty) {
      _setLocalError(l10n.forgotNeedCode);
      return;
    }
    if (!isValidOtp(code)) {
      _setLocalError(l10n.registerInvalidCode);
      return;
    }
    if (pwd.isEmpty) {
      _setLocalError(l10n.forgotNeedPassword);
      return;
    }
    if (!isValidPassword(pwd)) {
      _setLocalError(l10n.forgotInvalidPassword);
      return;
    }
    _setLocalError(null);
    try {
      await context.read<AuthProvider>().changePassword(email, code, pwd);
      if (!mounted) return;
      ErrorHandler.showSuccess(context, context.l10n.forgotSuccess);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) context.go('/auth/login');
    } catch (e) {
      if (!mounted) return;
      _setLocalError(
        ErrorHandler.getErrorMessage(e, defaultMessage: context.l10n.forgotFailed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final l10n = context.l10n;
    final error = _localError ?? auth.error;
    return AuthScaffold(
      showBack: true,
      onBack: () => context.go('/auth/login'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuthBrandHeader(
            title: l10n.forgotTitle,
            subtitle: l10n.forgotSubtitle,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onChanged: (_) => _setLocalError(null),
            decoration: AuthChrome.fieldDecoration(
              context: context,
              label: l10n.registerEmail,
              hint: l10n.forgotEmailHint,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => _setLocalError(null),
                  decoration: AuthChrome.fieldDecoration(
                    context: context,
                    label: l10n.registerCode,
                    hint: l10n.registerCodeHint,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              AuthCodeButton(
                countdown: authCodeCountdown,
                busy: authCodeSending,
                onPressed: _sendCode,
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pwdCtrl,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _reset(),
            onChanged: (_) => _setLocalError(null),
            decoration: AuthChrome.fieldDecoration(
              context: context,
              label: l10n.forgotNewPassword,
              hint: l10n.forgotNewPasswordHint,
              suffix: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: ShellSurface.ink.withValues(alpha: 0.45),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (error != null) ...[
            AuthErrorBanner(message: error),
            const SizedBox(height: 14),
          ],
          AuthPrimaryButton(
            label: l10n.forgotSubmit,
            loading: auth.loading,
            onPressed: _reset,
          ),
          const SizedBox(height: 12),
          AuthSecondaryLink(
            prefix: l10n.forgotRemember,
            action: l10n.forgotBackLogin,
            onTap: () => context.go('/auth/login'),
          ),
        ],
      ),
    );
  }
}
