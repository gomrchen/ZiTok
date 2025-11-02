import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/env.dart';
import '../../theme/theme_tokens.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
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
                    if (Env.isDev)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: Spacing.md),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.yellow.shade100,
                          borderRadius: Radii.sm,
                        ),
                        child: const Text('开发环境：仅格式校验，不调用后端', style: TextStyle(color: Colors.black87)),
                      ),
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: '手机号',
                        hintText: 'Enter your telephone number',
                      ),
                    ),
                    const SizedBox(height: Spacing.md),
                    TextField(
                      controller: _otpCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '验证码',
                        hintText: 'Enter 6-digit OTP',
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
                    const SizedBox(height: Spacing.lg),
                    if (auth.error != null)
                      Text(auth.error!, style: const TextStyle(color: Color(0xFFEF4444))),
                    const SizedBox(height: Spacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: auth.loading
                            ? null
                            : () async {
                                await context.read<AuthProvider>().register(
                                      _phoneCtrl.text.trim(),
                                      _otpCtrl.text.trim(),
                                      password: _pwdCtrl.text.trim().isEmpty ? null : _pwdCtrl.text.trim(),
                                    );
                                if (mounted && context.read<AuthProvider>().isAuthenticated) {
              context.go('/home');
                                }
                              },
                        child: auth.loading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
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