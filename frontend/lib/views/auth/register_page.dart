import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/theme_tokens.dart';
import '../../utils/validators.dart';
import '../../utils/error_handler.dart';

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
  bool _isPasswordVisible = false;
  int _countdown = 0;

  // 注册非空验证函数
  bool _validateInputs() {
    if (_usernameCtrl.text.trim().isEmpty) {
      _showError('请输入用户名');
      return false;
    }

    if (_emailCtrl.text.trim().isEmpty) {
      _showError('请输入邮箱');
      return false;
    }

    if (_pwdCtrl.text.trim().isEmpty) {
      _showError('请输入密码');
      return false;
    }

    if (_codeCtrl.text.trim().isEmpty) {
      _showError('请输入验证码');
      return false;
    }

    return true;
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

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
    // 检查邮箱是否为空
    if (_emailCtrl.text.isEmpty) {
      _showError('请先填写邮箱');
      return;
    }

    // 添加邮箱格式验证
    if (!isValidEmail(_emailCtrl.text)) {
      _showError('请输入有效的邮箱地址');
      return;
    }

    setState(() {
      _isSendingCode = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.sendVerificationCode(_emailCtrl.text);

      // 开始倒计时
      _startCountdown();

      if (mounted) {
        ErrorHandler.showSuccess(context, '验证码已发送，请查收邮箱');
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, e, prefix: '发送失败');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingCode = false;
        });
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
                    Text('ZiTok 短剧', style: theme.textTheme.titleLarge),
                    const SizedBox(height: Spacing.sm),
                    Text('竖屏连播 · 热门短剧', style: theme.textTheme.bodySmall),
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
                    const SizedBox(height: Spacing.lg),
                    // 表单
                    TextField(
                      controller: _pwdCtrl,
                      keyboardType: TextInputType.visiblePassword,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: '新密码',
                        hintText: '请设置密码',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
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
                                // 先验证输入
                                if (!_validateInputs()) {
                                  return;
                                }

                                await context.read<AuthProvider>().register(
                                  _usernameCtrl.text.trim(),
                                  _emailCtrl.text.trim(),
                                  _pwdCtrl.text.trim(),
                                  _codeCtrl.text.trim(),
                                );

                                if (!context.mounted) return;
                                if (context
                                    .read<AuthProvider>()
                                    .isRegistered) {
                                  // 注册成功后跳转到登录页，让用户手动登录
                                  context.go('/auth/login');
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
                            : const Text('注册后登录'),
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
