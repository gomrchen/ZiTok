import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';
import '../home/shell_surface.dart';
import 'settings_chrome.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _newPasswordCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _isSendingCode = false;
  int _countdown = 0;
  bool _isNewPasswordVisible = false;

  @override
  void dispose() {
    _newPasswordCtrl.dispose();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  bool _validateSendCodeInputs() {
    if (_emailCtrl.text.trim().isEmpty) {
      _showError('请输入邮箱');
      return false;
    }
    if (!isValidEmail(_emailCtrl.text)) {
      _showError('请输入有效的邮箱地址');
      return false;
    }
    return true;
  }

  bool _validateResetPasswordInputs() {
    if (!_validateSendCodeInputs()) return false;
    if (_codeCtrl.text.trim().isEmpty) {
      _showError('请输入验证码');
      return false;
    }
    if (!isValidOtp(_codeCtrl.text)) {
      _showError('验证码必须为6位数字');
      return false;
    }
    if (_newPasswordCtrl.text.trim().isEmpty) {
      _showError('请输入新密码');
      return false;
    }
    if (!isValidPassword(_newPasswordCtrl.text)) {
      _showError('新密码必须包含字母和数字，长度8-20位');
      return false;
    }
    return true;
  }

  void _startCountdown() {
    setState(() {
      _countdown = 60;
      _isSendingCode = true;
    });
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _countdown--);
      return _countdown > 0;
    }).whenComplete(() {
      if (mounted) setState(() => _isSendingCode = false);
    });
  }

  Future<void> _sendVerificationCode() async {
    if (!_validateSendCodeInputs()) return;
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.sendVerificationCode(_emailCtrl.text);
      _startCountdown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('验证码已发送，请查收邮箱'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      _showError('发送失败: $e');
    }
  }

  Future<void> _resetPassword() async {
    if (!_validateResetPasswordInputs()) return;
    try {
      await context.read<AuthProvider>().changePassword(
            _emailCtrl.text.trim(),
            _codeCtrl.text.trim(),
            _newPasswordCtrl.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('密码重置成功，请登录'), behavior: SnackBarBehavior.floating),
      );
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) context.go('/auth/login');
      });
    } catch (e) {
      _showError('重置失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return SettingsChrome.page(
      title: '安全',
      body: ListView(
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
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A1F2A), Color(0xFF2A2418)],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  child: const Icon(Icons.shield_rounded, color: Color(0xFFE8B84A)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '重置登录密码',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '通过注册邮箱验证后设置新密码',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.62), fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('新密码', style: ShellSurface.bodyStrong),
          const SizedBox(height: 8),
          TextField(
            controller: _newPasswordCtrl,
            obscureText: !_isNewPasswordVisible,
            decoration: SettingsChrome.fieldDecoration(
              label: '新密码',
              hint: '8-20 位，含字母与数字',
              suffix: IconButton(
                icon: Icon(
                  _isNewPasswordVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                  color: ShellSurface.muted,
                ),
                onPressed: () => setState(() => _isNewPasswordVisible = !_isNewPasswordVisible),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('注册邮箱', style: ShellSurface.bodyStrong),
          const SizedBox(height: 8),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: SettingsChrome.fieldDecoration(
              label: '邮箱',
              hint: '用于接收验证码',
            ),
          ),
          const SizedBox(height: 16),
          Text('验证码', style: ShellSurface.bodyStrong),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: SettingsChrome.fieldDecoration(
                    label: '验证码',
                    hint: '6 位数字',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: _isSendingCode ? null : _sendVerificationCode,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ShellSurface.coral,
                    side: BorderSide(color: ShellSurface.coral.withValues(alpha: 0.45)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: Text(
                    _countdown > 0 ? '${_countdown}s' : '获取验证码',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
          if (auth.error != null) ...[
            const SizedBox(height: 12),
            Text(auth.error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
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
                : const Text('确认重置'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.go('/settings'),
            style: SettingsChrome.ghostButton,
            child: const Text('返回设置'),
          ),
        ],
      ),
    );
  }
}
