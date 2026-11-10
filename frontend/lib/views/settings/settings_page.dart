import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n_ext.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../home/shell_surface.dart';
import 'settings_chrome.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SettingsProvider>();
    final tp = context.watch<ThemeProvider>();
    final l10n = context.l10n;

    return SettingsChrome.page(
      title: l10n.settingsTitle,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          ShellSurface.pagePad,
          8,
          ShellSurface.pagePad,
          28,
        ),
        children: [
          const _HeroBanner(),
          const SizedBox(height: 22),
          SettingsChrome.section(
            title: l10n.settingsAccountSecurity,
            subtitle: l10n.settingsAccountSecuritySub,
            children: [
              SettingsChrome.navTile(
                icon: Icons.person_rounded,
                tint: const Color(0xFFE8F7F4),
                iconColor: ShellSurface.accent,
                title: l10n.settingsAccount,
                subtitle: l10n.settingsAccountSub,
                onTap: () => context.push('/settings/account-settings'),
              ),
              SettingsChrome.navTile(
                icon: Icons.lock_rounded,
                tint: const Color(0xFFFFE8C8),
                iconColor: const Color(0xFFC47A12),
                title: l10n.settingsSecurity,
                subtitle: l10n.settingsSecuritySub,
                onTap: () => context.push('/settings/change-password'),
              ),
            ],
          ),
          const SizedBox(height: ShellSurface.sectionGap),
          SettingsChrome.section(
            title: l10n.settingsNotify,
            subtitle: l10n.settingsNotifySub,
            children: [
              SettingsChrome.switchTile(
                icon: Icons.notifications_active_rounded,
                tint: const Color(0xFFFFE0D8),
                iconColor: ShellSurface.coral,
                title: l10n.settingsRing,
                subtitle: l10n.settingsRingSub,
                value: sp.pushNotifications,
                onChanged: sp.togglePush,
              ),
              SettingsChrome.switchTile(
                icon: Icons.mail_rounded,
                tint: const Color(0xFFE8E6E2),
                iconColor: ShellSurface.muted,
                title: l10n.settingsEmailNotify,
                subtitle: l10n.settingsEmailNotifySub,
                value: sp.emailNotifications,
                onChanged: sp.toggleEmail,
              ),
              SettingsChrome.switchTile(
                icon: Icons.chat_bubble_rounded,
                tint: const Color(0xFFD8F5F0),
                iconColor: const Color(0xFF0F9B8A),
                title: l10n.settingsMsgPush,
                subtitle: l10n.settingsMsgPushSub,
                value: sp.messagePush,
                onChanged: sp.toggleMessagePush,
              ),
            ],
          ),
          const SizedBox(height: ShellSurface.sectionGap),
          SettingsChrome.section(
            title: l10n.settingsPlayback,
            subtitle: l10n.settingsPlaybackSub,
            children: [
              SettingsChrome.navTile(
                icon: Icons.language_rounded,
                tint: const Color(0xFFE8F0FF),
                iconColor: const Color(0xFF3B6FD9),
                title: l10n.settingsLanguage,
                subtitle: sp.language,
                onTap: () async {
                  final lang = await _showLanguageSheet(context, sp.language);
                  if (lang != null) sp.setLanguage(lang);
                },
              ),
              SettingsChrome.switchTile(
                icon: Icons.dark_mode_rounded,
                tint: const Color(0xFFE8E6E2),
                iconColor: ShellSurface.muted,
                title: l10n.settingsNightMode,
                subtitle: l10n.settingsNightModeSub,
                value: tp.themeName == 'dark',
                onChanged: (_) => tp.toggleDark(),
              ),
              SettingsChrome.switchTile(
                icon: Icons.apps_rounded,
                tint: const Color(0xFFFFE0D8),
                iconColor: ShellSurface.coral,
                title: l10n.settingsPlayerMore,
                subtitle: l10n.settingsPlayerMoreSub,
                value: sp.playerMoreButton,
                onChanged: sp.togglePlayerMoreButton,
              ),
              SettingsChrome.switchTile(
                icon: Icons.timer_outlined,
                tint: const Color(0xFFFFE8C8),
                iconColor: const Color(0xFFC47A12),
                title: l10n.settingsAutoNext,
                subtitle: l10n.settingsAutoNextSub,
                value: sp.autoNextCountdown,
                onChanged: sp.toggleAutoNextCountdown,
              ),
            ],
          ),
          const SizedBox(height: ShellSurface.sectionGap),
          SettingsChrome.section(
            title: l10n.settingsCompliance,
            children: [
              SettingsChrome.navTile(
                icon: Icons.child_care_rounded,
                tint: const Color(0xFFE8F7F4),
                iconColor: ShellSurface.accent,
                title: l10n.settingsYouth,
                subtitle: l10n.settingsYouthSub,
                onTap: () => _showYouthDialog(context),
              ),
              SettingsChrome.navTile(
                icon: Icons.flag_rounded,
                tint: const Color(0xFFFFE0D8),
                iconColor: ShellSurface.coral,
                title: l10n.settingsFeedback,
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.settingsFeedbackDone),
                    behavior: SnackBarBehavior.floating,
                  ),
                ),
              ),
              SettingsChrome.navTile(
                icon: Icons.info_rounded,
                tint: const Color(0xFFE8E6E2),
                iconColor: ShellSurface.muted,
                title: l10n.settingsAbout,
                subtitle: l10n.settingsAboutSub,
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: l10n.appTitle,
                  applicationVersion: '0.1.0',
                  applicationLegalese: l10n.settingsAboutLegalese,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showYouthDialog(BuildContext context) {
    final l10n = context.l10n;
    showDialog<void>(
      context: context,
      builder: (ctx) => SettingsChrome.dialog(
        context: ctx,
        title: l10n.settingsYouth,
        content: Text(
          l10n.settingsYouthDialog,
          style: ShellSurface.captionOf(ctx).copyWith(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              l10n.settingsGotIt,
              style: const TextStyle(color: ShellSurface.coral, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _showLanguageSheet(BuildContext context, String current) {
    final l10n = context.l10n;
    final langs = [SettingsProvider.langZh, SettingsProvider.langEn];
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: ShellSurface.cardOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        final ink = ShellSurface.inkOf(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ink.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.settingsSelectLanguage,
                    style: TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 8),
                for (final lang in langs)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(lang, style: ShellSurface.bodyStrongOf(ctx)),
                    trailing: current == lang
                        ? const Icon(Icons.check_rounded, color: ShellSurface.coral)
                        : null,
                    onTap: () => Navigator.pop(ctx, lang),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1F2A), Color(0xFF2A2030), Color(0xFF1C2422)],
        ),
        boxShadow: [
          BoxShadow(
            color: ShellSurface.ink.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [Color(0xFFFF8A6B), ShellSurface.coral],
              ),
            ),
            child: const Icon(Icons.tune_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.settingsHeroTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.settingsHeroSubtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
