import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../home/shell_surface.dart';
import 'settings_chrome.dart';

class AccountSettingsPage extends StatelessWidget {
  const AccountSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsChrome.page(
      title: '账户设置',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          ShellSurface.pagePad,
          12,
          ShellSurface.pagePad,
          28,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: ShellSurface.card,
              border: Border.all(color: ShellSurface.line),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [ShellSurface.accent, Color(0xFF0F9B8A)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: ShellSurface.accent.withValues(alpha: 0.28),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('Z', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('当前账号', style: ShellSurface.caption),
                      const SizedBox(height: 4),
                      Text('ZiTok 演示账号', style: ShellSurface.bodyStrong.copyWith(fontSize: 16)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ShellSurface.sectionGap),
          SettingsChrome.section(
            title: '账户管理',
            subtitle: '切换或退出当前登录态',
            children: [
              SettingsChrome.navTile(
                icon: Icons.switch_account_rounded,
                tint: const Color(0xFFE8F0FF),
                iconColor: const Color(0xFF3B6FD9),
                title: '切换账号',
                subtitle: '在已保存账号间快速切换',
                onTap: () => context.push('/settings/account-switcher'),
              ),
              SettingsChrome.navTile(
                icon: Icons.logout_rounded,
                tint: const Color(0xFFFFE0D8),
                iconColor: ShellSurface.coral,
                title: '退出当前账号',
                subtitle: '清除本机登录态',
                titleColor: ShellSurface.coral,
                showChevron: false,
                onTap: () => _confirmLogout(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ShellSurface.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('退出登录', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('确定要退出当前账号吗？', style: ShellSurface.caption.copyWith(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: ShellSurface.ink.withValues(alpha: 0.55))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _logout(context);
            },
            style: TextButton.styleFrom(foregroundColor: ShellSurface.coral),
            child: const Text('确定', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _logout(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: ShellSurface.coral)),
    );

    authProvider.logout().then((_) {
      if (!context.mounted) return;
      context.go('/welcome');
    }).catchError((error) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('登出失败: $error'), behavior: SnackBarBehavior.floating),
      );
    });
  }
}
