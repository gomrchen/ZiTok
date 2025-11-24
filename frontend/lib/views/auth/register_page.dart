import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/theme_tokens.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _isSendingCode = false;
  int _countdown = 0;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
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
    if (_emailCtrl.text.isEmpty) {
      // 显示错误提示
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请先填写邮箱')));
      }
      return;
    }

    try {
      // TODO: 实现发送验证码的逻辑
      print('发送验证码到: ${_emailCtrl.text}');
      _startCountdown();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('验证码已发送，请查收邮箱')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('发送失败: ${e.toString()}')));
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
                    Text('知音', style: theme.textTheme.titleLarge),
                    const SizedBox(height: Spacing.sm),
                    Text('支持笔记功能的视频社区', style: theme.textTheme.bodySmall),
                    const SizedBox(height: Spacing.lg),
                    TextField(
                      controller: _usernameCtrl,
                      keyboardType: TextInputType.text,
                      decoration: const InputDecoration(
                        labelText: '用户名',
                        hintText: 'Enter your username',
                      ),
                    ),
                    const SizedBox(height: Spacing.md),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: '邮箱',
                        hintText: 'Enter your email',
                      ),
                    ),
                    const SizedBox(height: Spacing.md),
                    TextField(
                      controller: _pwdCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: '密码（可选）',
                        hintText: 'Set an optional password',
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
                            onPressed: _isSendingCode
                                ? null
                                : _sendVerificationCode,
                            child: _countdown > 0
                                ? Text('${_countdown}s')
                                : const Text('获取验证码'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.lg),
                    if (auth.error != null)
                      Text(
                        auth.error!,
                        style: const TextStyle(color: Color(0xFFEF4444)),
                      ),
                    const SizedBox(height: Spacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: auth.loading
                            ? null
                            : () async {
                                await context.read<AuthProvider>().register(
                                  _usernameCtrl.text.trim(),
                                  _emailCtrl.text.trim(),
                                  _pwdCtrl.text.trim(),
                                  _codeCtrl.text.trim(),
                                );
                                if (mounted &&
                                    context
                                        .read<AuthProvider>()
                                        .isAuthenticated) {
                                  context.go('/home');
                                }
                              },
                        child: auth.loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('注册并进入应用'),
                      ),
                    ),
                    const SizedBox(height: Spacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => context.go('/auth/login'),
                        child: RichText(
                          text: TextSpan(
                            text: '已有账号？',
                            style: theme.textTheme.bodyMedium,
                            children: [
                              TextSpan(
                                text: ' 登录',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
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
