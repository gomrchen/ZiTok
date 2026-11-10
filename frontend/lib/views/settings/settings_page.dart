import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/theme_tokens.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SettingsProvider>();
    final tp = context.read<ThemeProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.md),
        children: [
          _Section(
            title: '账户与安全',
            children: [
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('账户'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/account-settings'),
              ),
              ListTile(
                leading: const Icon(Icons.security),
                title: const Text('安全'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/change-password'),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          _Section(
            title: '通知与消息',
            children: [
              SwitchListTile(
                value: sp.pushNotifications,
                title: const Text('铃声通知'),
                onChanged: sp.togglePush,
              ),
              SwitchListTile(
                value: sp.emailNotifications,
                title: const Text('邮件通知'),
                onChanged: sp.toggleEmail,
              ),
              SwitchListTile(
                value: sp.messagePush,
                title: const Text('消息推送'),
                onChanged: sp.toggleMessagePush,
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          _Section(
            title: '偏好设置',
            children: [
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('语言'),
                subtitle: Text(sp.language),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final lang = await _showLanguageSheet(context, sp.language);
                  if (lang != null) sp.setLanguage(lang);
                },
              ),
              SwitchListTile(
                value: tp.themeName == 'dark',
                title: const Text('夜晚模式'),
                onChanged: (_) => tp.toggleDark(),
              ),
              ListTile(
                leading: const Icon(Icons.child_care_outlined),
                title: const Text('青少年模式'),
                subtitle: const Text('合规占位：可限制付费与社交'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('青少年模式'),
                    content: const Text('一期占位：开启后将限制付费解锁与私信（待完善）。'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('知道了')),
                    ],
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('举报与反馈'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已记录反馈入口（一期占位）')),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('关于'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'ZiTok 短剧',
                  applicationVersion: '0.1.0',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<String?> _showLanguageSheet(
    BuildContext context,
    String current,
  ) async {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        const langs = ['简体中文', 'English'];
        return RadioGroup<String>(
          groupValue: current,
          onChanged: (v) => Navigator.pop(context, v),
          child: ListView(
            children: langs
                .map(
                  (e) => RadioListTile<String>(
                    value: e,
                    title: Text(e),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
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
