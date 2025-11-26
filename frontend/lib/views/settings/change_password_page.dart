import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../theme/theme_tokens.dart';
import '../../utils/validators.dart';

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
 // bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    _newPasswordCtrl.dispose();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }
  
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
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
    if (_emailCtrl.text.trim().isEmpty) {
      _showError('请输入邮箱');
      return false;
    }
    
    if (!isValidEmail(_emailCtrl.text)) {
      _showError('请输入有效的邮箱地址');
      return false;
    }
    
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
    
    // 倒计时逻辑
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _countdown--;
        });
        return _countdown > 0;
      }
      return false;
    }).whenComplete(() {
      if (mounted) {
        setState(() {
          _isSendingCode = false;
        });
      }
    });
  }

  Future<void> _sendVerificationCode() async {
    // 验证输入
    if (!_validateSendCodeInputs()) {
      return;
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.sendVerificationCode(_emailCtrl.text);
      
      _startCountdown();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('验证码已发送，请查收邮箱')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _resetPassword() async {
    // 验证输入
    if (!_validateResetPasswordInputs()) {
      return;
    }

    try {
      await context.read<AuthProvider>().changePassword(
        _emailCtrl.text.trim(),
         _codeCtrl.text.trim(),
         _newPasswordCtrl.text.trim(),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('密码重置成功，请登录')),
        );
        
        // 返回登录页面
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            context.go('/auth/login');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('重置失败: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    
    return Scaffold(

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: Spacing.xl),
                    // 标题与副标题
                    Text('重置密码', style: theme.textTheme.titleLarge),
                    const SizedBox(height: Spacing.sm),
                    Text('请填写以下信息重置您的密码', style: theme.textTheme.bodySmall),
                    const SizedBox(height: Spacing.lg),
                    // 表单
                    TextField(
                      controller: _newPasswordCtrl,
                      keyboardType: TextInputType.visiblePassword,
                      obscureText: !_isNewPasswordVisible,
                      decoration: InputDecoration(
                        labelText: '新密码',
                        hintText: '请设置新密码',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isNewPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _isNewPasswordVisible = !_isNewPasswordVisible;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.md),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: '邮箱',
                        hintText: '请输入您的注册邮箱',
                      ),
                    ),
                    const SizedBox(height: Spacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _codeCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '验证码',
                              hintText: '请输入验证码',
                            ),
                          ),
                        ),
                        const SizedBox(width: Spacing.md),
                        SizedBox(
                          width: 120,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: _isSendingCode ? null : _sendVerificationCode,
                            child: _countdown > 0
                                ? Text('${_countdown}s')
                                : const Text('获取验证码'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.lg),
                    if (auth.error != null)
                      Text(auth.error!, style: const TextStyle(color: Color(0xFFEF4444))),
                    const SizedBox(height: Spacing.md),
                    // 主按钮
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: auth.loading ? null : _resetPassword,
                        child: auth.loading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('重置密码'),
                      ),
                    ),
                    const SizedBox(height: Spacing.md),
                    // 返回登录按钮
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => context.go('/auth/login'),
                        child: RichText(
                          text: TextSpan(
                            text: '记得密码？',
                            style: theme.textTheme.bodyMedium,
                            children: [
                              TextSpan(
                                text: ' 返回设置',
                                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.xl),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}