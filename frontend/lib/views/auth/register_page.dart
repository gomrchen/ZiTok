import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n_ext.dart';
import '../../providers/auth_provider.dart';
import '../../utils/error_handler.dart';
import '../../utils/validators.dart';
import '../home/shell_surface.dart';
import 'auth_chrome.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with AuthCodeCountdown {
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
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
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _setLocalError(String? msg) => setState(() => _localError = msg);

  bool _validate() {
    final l10n = context.l10n;
    if (_usernameCtrl.text.trim().isEmpty) {
      _setLocalError(l10n.registerNeedUsername);
      return false;
    }
    if (_emailCtrl.text.trim().isEmpty) {
      _setLocalError(l10n.registerNeedEmail);
      return false;
    }
    if (!isValidEmail(_emailCtrl.text.trim())) {
      _setLocalError(l10n.registerInvalidEmail);
      return false;
    }
    if (_pwdCtrl.text.isEmpty) {
      _setLocalError(l10n.registerNeedPassword);
      return false;
    }
    if (!isValidPassword(_pwdCtrl.text)) {
      _setLocalError(l10n.registerInvalidPassword);
      return false;
    }
    if (_codeCtrl.text.trim().isEmpty) {
      _setLocalError(l10n.registerNeedCode);
      return false;
    }
    if (!isValidOtp(_codeCtrl.text.trim())) {
      _setLocalError(l10n.registerInvalidCode);
      return false;
    }
    _setLocalError(null);
    return true;
  }

  Future<void> _sendCode() async {
    final l10n = context.l10n;
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _setLocalError(l10n.registerNeedEmailFirst);
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

  Future<void> _submit(AuthProvider auth) async {
    if (!_validate()) return;
    await auth.register(
      _usernameCtrl.text.trim(),
      _emailCtrl.text.trim(),
      _pwdCtrl.text,
      _codeCtrl.text.trim(),
    );
    if (!mounted) return;
    if (auth.isRegistered) {
      ErrorHandler.showSuccess(context, context.l10n.registerSuccess);
      context.go('/auth/login');
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
            title: l10n.registerTitle,
            subtitle: l10n.registerSubtitle,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _usernameCtrl,
            textInputAction: TextInputAction.next,
            onChanged: (_) => _setLocalError(null),
            decoration: AuthChrome.fieldDecoration(
              context: context,
              label: l10n.loginUsername,
              hint: l10n.registerUsernameHint,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onChanged: (_) => _setLocalError(null),
            decoration: AuthChrome.fieldDecoration(
              context: context,
              label: l10n.registerEmail,
              hint: l10n.registerEmailHint,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pwdCtrl,
            obscureText: _obscure,
            textInputAction: TextInputAction.next,
            onChanged: (_) => _setLocalError(null),
            decoration: AuthChrome.fieldDecoration(
              context: context,
              label: l10n.loginPassword,
              hint: l10n.registerPasswordHint,
              suffix: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: ShellSurface.ink.withValues(alpha: 0.45),
                ),
              ),
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
                  textInputAction: TextInputAction.done,
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
          const SizedBox(height: 16),
          if (error != null) ...[
            AuthErrorBanner(message: error),
            const SizedBox(height: 14),
          ],
          AuthPrimaryButton(
            label: l10n.registerSubmit,
            loading: auth.loading,
            onPressed: () => _submit(auth),
          ),
          const SizedBox(height: 12),
          AuthSecondaryLink(
            prefix: l10n.registerHasAccount,
            action: l10n.registerBackLogin,
            onTap: () => context.go('/auth/login'),
          ),
        ],
      ),
    );
  }
}
