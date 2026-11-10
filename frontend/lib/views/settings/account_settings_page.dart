import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n_ext.dart';
import '../../providers/auth_provider.dart';
import '../home/shell_surface.dart';
import 'settings_chrome.dart';

class AccountSettingsPage extends StatelessWidget {
  const AccountSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SettingsChrome.page(
      title: l10n.settingsAccountTitle,
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
              color: ShellSurface.cardOf(context),
              border: Border.all(color: ShellSurface.lineOf(context)),
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
                    child: Text(
                      'Z',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.settingsCurrentAccount, style: ShellSurface.captionOf(context)),
                      const SizedBox(height: 4),
                      Text(
                        l10n.profileDemoBio,
                        style: ShellSurface.bodyStrongOf(context).copyWith(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ShellSurface.sectionGap),
          SettingsChrome.section(
            title: l10n.settingsAccountManage,
            subtitle: l10n.settingsAccountManageSub,
            children: [
              SettingsChrome.navTile(
                icon: Icons.switch_account_rounded,
                tint: const Color(0xFFE8F0FF),
                iconColor: const Color(0xFF3B6FD9),
                title: l10n.settingsSwitchAccount,
                subtitle: l10n.settingsSwitchAccountSub,
                onTap: () => context.push('/settings/account-switcher'),
              ),
              SettingsChrome.navTile(
                icon: Icons.logout_rounded,
                tint: const Color(0xFFFFE0D8),
                iconColor: ShellSurface.coral,
                title: l10n.settingsLogoutCurrent,
                subtitle: l10n.settingsLogoutSub,
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
    final l10n = context.l10n;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ShellSurface.cardOf(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(l10n.settingsLogout, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          l10n.settingsLogoutConfirm,
          style: ShellSurface.captionOf(context).copyWith(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              l10n.commonCancel,
              style: TextStyle(color: ShellSurface.inkOf(context).withValues(alpha: 0.55)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _logout(context);
            },
            style: TextButton.styleFrom(foregroundColor: ShellSurface.coral),
            child: Text(
              l10n.commonConfirm,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final l10n = context.l10n;
    final authProvider = context.read<AuthProvider>();
    final nav = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: ShellSurface.coral),
      ),
    );

    try {
      await authProvider.logout();
      if (!context.mounted) return;
      if (nav.canPop()) nav.pop();
      context.go('/welcome');
    } catch (error) {
      if (!context.mounted) return;
      if (nav.canPop()) nav.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.settingsLogoutFailed('$error')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
