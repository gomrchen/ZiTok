import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../theme/theme_tokens.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _isSendingCode = false;
  int _countdown = 0;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
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
    if (_usernameCtrl.text.isEmpty || _emailCtrl.text.isEmpty) {
      // 显示错误提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请填写用户名和邮箱')),
        );
      }
      return;
    }

    try {
      // TODO: 实现发送验证码的逻辑
      // 这里应该调用auth provider或repository的方法
      print('发送验证码到: ${_emailCtrl.text}');
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
    if (_usernameCtrl.text.isEmpty || 
        _emailCtrl.text.isEmpty || 
        _codeCtrl.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请填写所有必填字段')),
        );
      }
      return;
    }

    // TODO: 实现重置密码的逻辑
    print('重置密码: 用户名=${_usernameCtrl.text}, 邮箱=${_emailCtrl.text}, 验证码=${_codeCtrl.text}');
    
    // 模拟成功
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
                      controller: _usernameCtrl,
                      keyboardType: TextInputType.text,
                      decoration: const InputDecoration(
                        labelText: '用户名',
                        hintText: '请输入您的用户名',
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
                                text: ' 返回登录',
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