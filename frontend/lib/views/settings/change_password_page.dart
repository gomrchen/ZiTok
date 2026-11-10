import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n_ext.dart';
import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';
import '../auth/auth_chrome.dart';
import '../home/shell_surface.dart';
import 'settings_chrome.dart';

/// 设置 → 安全：邮箱验证码重置密码（与忘记密码同源能力）
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage>
    with AuthCodeCountdown {
  final _newPasswordCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _obscure = true;
  String? _localError;

  @override
  void dispose() {
    _newPasswordCtrl.dispose();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _setLocalError(String? msg) => setState(() => _localError = msg);

  bool _validateSendCodeInputs() {
    final l10n = context.l10n;
    if (_emailCtrl.text.trim().isEmpty) {
      _setLocalError(l10n.forgotNeedEmail);
      return false;
    }
    if (!isValidEmail(_emailCtrl.text.trim())) {
      _setLocalError(l10n.registerInvalidEmail);
      return false;
    }
    return true;
  }

  Future<void> _sendVerificationCode() async {
    if (!_validateSendCodeInputs()) return;
    setState(() {
      authCodeSending = true;
      _localError = null;
    });
    try {
      await context.read<AuthProvider>().sendVerificationCode(_emailCtrl.text.trim());
      if (!mounted) return;
      startAuthCodeCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.codeSent), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;
      _setLocalError('${context.l10n.codeSendFailed}: $e');
      setState(() => authCodeSending = false);
    }
  }

  Future<void> _resetPassword() async {
    final l10n = context.l10n;
    if (!_validateSendCodeInputs()) return;
    if (_codeCtrl.text.trim().isEmpty) {
      _setLocalError(l10n.forgotNeedCode);
      return;
    }
    if (!isValidOtp(_codeCtrl.text.trim())) {
      _setLocalError(l10n.registerInvalidCode);
      return;
    }
    if (_newPasswordCtrl.text.trim().isEmpty) {
      _setLocalError(l10n.forgotNeedPassword);
      return;
    }
    if (!isValidPassword(_newPasswordCtrl.text)) {
      _setLocalError(l10n.forgotInvalidPassword);
      return;
    }
    _setLocalError(null);
    try {
      await context.read<AuthProvider>().changePassword(
            _emailCtrl.text.trim(),
            _codeCtrl.text.trim(),
            _newPasswordCtrl.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.forgotSuccess), behavior: SnackBarBehavior.floating),
      );
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) context.go('/auth/login');
      });
    } catch (e) {
      if (!mounted) return;
      _setLocalError('${l10n.forgotFailed}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final l10n = context.l10n;
    final error = _localError ?? auth.error;
    final ink = ShellSurface.inkOf(context);

    return AnnotatedRegion(
      value: ShellSurface.systemUiOf(context),
      child: Scaffold(
        backgroundColor: ShellSurface.canvasOf(context),
        appBar: ShellSurface.appBar(title: l10n.settingsSecurity, context: context),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              ShellSurface.pagePad,
              8,
              ShellSurface.pagePad,
              28,
            ),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: ShellSurface.lineOf(context)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: ShellSurface.isDark(context)
                        ? const [Color(0xFF243044), Color(0xFF4A3720)]
                        : const [Color(0xFF1A1F2A), Color(0xFF2A2418)],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      child: const Icon(Icons.shield_rounded, color: Color(0xFFE8B84A)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.settingsSecurityHeroTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.settingsSecurityHeroSub,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.68),
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _newPasswordCtrl,
                obscureText: _obscure,
                style: TextStyle(color: ink, fontSize: 15),
                onChanged: (_) => _setLocalError(null),
                decoration: AuthChrome.fieldDecoration(
                  context: context,
                  label: l10n.forgotNewPassword,
                  hint: l10n.forgotNewPasswordHint,
                  suffix: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: ShellSurface.mutedOf(context),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: ink, fontSize: 15),
                onChanged: (_) => _setLocalError(null),
                decoration: AuthChrome.fieldDecoration(
                  context: context,
                  label: l10n.settingsRegisteredEmail,
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
                      style: TextStyle(color: ink, fontSize: 15),
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
                    onPressed: _sendVerificationCode,
                  ),
                ],
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: auth.loading ? null : _resetPassword,
                style: SettingsChrome.primaryButton,
                child: auth.loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(l10n.forgotSubmit),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.pop(),
                style: SettingsChrome.ghostButtonOf(context),
                child: Text(l10n.settingsBackToSettings),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
