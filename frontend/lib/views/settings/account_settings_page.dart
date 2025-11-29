import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/theme_tokens.dart';
import '../../providers/auth_provider.dart';

class AccountSettingsPage extends StatelessWidget {
  const AccountSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('账户设置')),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.md),
        children: [
          const SizedBox(height: Spacing.md),
          _Section(
            title: '账户管理',
            children: [
              ListTile(
                leading: const Icon(Icons.switch_account),
                title: const Text('切换账号'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/account-switcher'),
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('退出当前账号'),
                textColor: Colors.red,
                onTap: () => _confirmLogout(context),
              ),
            ],
          ),

        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _logout(context);
            },
            child: const Text('确定'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  void _logout(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // 执行登出操作
    authProvider
        .logout()
        .then((_) {
          // 清除所有路由栈并跳转到欢迎界面
          context.go('/welcome');
        })
        .catchError((error) {
          Navigator.pop(context); // 关闭加载对话框
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('登出失败: $error')));
        });
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$title 区块',
      child: Card(
        elevation: 0,
        clipBehavior: Clip.hardEdge,
        child: Column(
          children: [
            Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.sm,
              ),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            ...children,
          ],
        ),
      ),
    );
  }
}
