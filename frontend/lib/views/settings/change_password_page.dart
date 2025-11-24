import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/theme_tokens.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _showOldPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  Widget _buildPasswordField(
    TextEditingController controller,
    String labelText,
    bool showPassword,
    Function(bool) onToggleVisibility, {
    required String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !showPassword,
      decoration: InputDecoration(
        labelText: labelText,
        suffixIcon: IconButton(
          icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility),
          onPressed: () => onToggleVisibility(!showPassword),
        ),
      ),
      validator: validator,
    );
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      // 调用认证提供者的修改密码方法
      await authProvider.changePassword(
        _emailCtrl.text,
        _oldPasswordController.text,
        _newPasswordController.text,
      );

      // 显示成功提示
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('密码修改成功')));

      // 清空表单
      _oldPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      // 返回上一页
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('修改密码')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.md),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 错误提示
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(Spacing.md),
                    margin: const EdgeInsets.only(bottom: Spacing.md),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: '邮箱',
                        hintText: 'Enter your email',
                      ),
                    ),
                // 旧密码
                Container(
                  margin: const EdgeInsets.only(bottom: Spacing.md),
                  child: _buildPasswordField(
                    _oldPasswordController,
                    '当前密码',
                    _showOldPassword,
                    (value) => setState(() => _showOldPassword = value),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入旧密码';
                      }
                      return null;
                    },
                  ),
                ),
                // 新密码
                Container(
                  margin: const EdgeInsets.only(bottom: Spacing.md),
                  child: _buildPasswordField(
                    _newPasswordController,
                    '新密码',
                    _showNewPassword,
                    (value) => setState(() => _showNewPassword = value),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入新密码';
                      }
                      if (value.length < 6) {
                        return '新密码长度不能少于6位';
                      }
                      if (value == _oldPasswordController.text) {
                        return '新密码不能与旧密码相同';
                      }
                      return null;
                    },
                  ),
                ),
                // 确认新密码
                Container(
                  margin: const EdgeInsets.only(bottom: Spacing.lg),
                  child: _buildPasswordField(
                    _confirmPasswordController,
                    '确认新密码',
                    _showConfirmPassword,
                    (value) => setState(() => _showConfirmPassword = value),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请确认新密码';
                      }
                      if (value != _newPasswordController.text) {
                        return '两次输入的密码不一致';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: Spacing.md),

                // 提交按钮
                ElevatedButton(
                  onPressed: _isLoading ? null : _changePassword,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: Spacing.md),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('确认修改'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
