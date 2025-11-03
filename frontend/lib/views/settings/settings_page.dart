import 'package:flutter/material.dart';
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
              ListTile(leading: const Icon(Icons.person), title: const Text('账户'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
              ListTile(leading: const Icon(Icons.lock), title: const Text('隐私'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
              ListTile(leading: const Icon(Icons.security), title: const Text('安全'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
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
                leading: const Icon(Icons.info_outline),
                title: const Text('关于'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: '知音App',
                  applicationVersion: '0.1.0',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<String?> _showLanguageSheet(BuildContext context, String current) async {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        const langs = ['简体中文', 'English'];
        return ListView(
          children: langs
              .map((e) => RadioListTile<String>(
                    value: e,
                    groupValue: current,
                    title: Text(e),
                    onChanged: (v) => Navigator.pop(context, v),
                  ))
              .toList(),
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
              padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
              child: Text(title, style: Theme.of(context).textTheme.titleMedium),
            ),
            const Divider(height: 1),
            ...children,
          ],
        ),
      ),
    );
  }
}