import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

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

    return SettingsChrome.page(
      title: '设置',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          ShellSurface.pagePad,
          8,
          ShellSurface.pagePad,
          28,
        ),
        children: [
          _HeroBanner(),
          const SizedBox(height: 22),
          SettingsChrome.section(
            title: '账户与安全',
            subtitle: '管理登录身份与密码',
            children: [
              SettingsChrome.navTile(
                icon: Icons.person_rounded,
                tint: const Color(0xFFE8F7F4),
                iconColor: ShellSurface.accent,
                title: '账户',
                subtitle: '切换账号 / 退出登录',
                onTap: () => context.push('/settings/account-settings'),
              ),
              SettingsChrome.navTile(
                icon: Icons.lock_rounded,
                tint: const Color(0xFFFFE8C8),
                iconColor: const Color(0xFFC47A12),
                title: '安全',
                subtitle: '邮箱验证重置密码',
                onTap: () => context.push('/settings/change-password'),
              ),
            ],
          ),
          const SizedBox(height: ShellSurface.sectionGap),
          SettingsChrome.section(
            title: '通知与消息',
            subtitle: '控制提醒触达方式',
            children: [
              SettingsChrome.switchTile(
                icon: Icons.notifications_active_rounded,
                tint: const Color(0xFFFFE0D8),
                iconColor: ShellSurface.coral,
                title: '铃声通知',
                subtitle: '重要互动即时提醒',
                value: sp.pushNotifications,
                onChanged: sp.togglePush,
              ),
              SettingsChrome.switchTile(
                icon: Icons.mail_rounded,
                tint: const Color(0xFFE8E6E2),
                iconColor: ShellSurface.muted,
                title: '邮件通知',
                subtitle: '账单与安全邮件',
                value: sp.emailNotifications,
                onChanged: sp.toggleEmail,
              ),
              SettingsChrome.switchTile(
                icon: Icons.chat_bubble_rounded,
                tint: const Color(0xFFD8F5F0),
                iconColor: const Color(0xFF0F9B8A),
                title: '消息推送',
                subtitle: '系统与运营推送',
                value: sp.messagePush,
                onChanged: sp.toggleMessagePush,
              ),
            ],
          ),
          const SizedBox(height: ShellSurface.sectionGap),
          SettingsChrome.section(
            title: '播放与偏好',
            subtitle: '短剧观看体验细调',
            children: [
              SettingsChrome.navTile(
                icon: Icons.language_rounded,
                tint: const Color(0xFFE8F0FF),
                iconColor: const Color(0xFF3B6FD9),
                title: '语言',
                subtitle: sp.language,
                onTap: () async {
                  final lang = await _showLanguageSheet(context, sp.language);
                  if (lang != null) sp.setLanguage(lang);
                },
              ),
              SettingsChrome.switchTile(
                icon: Icons.dark_mode_rounded,
                tint: const Color(0xFFE8E6E2),
                iconColor: ShellSurface.ink,
                title: '夜晚模式',
                subtitle: '降低屏幕亮度刺激',
                value: tp.themeName == 'dark',
                onChanged: (_) => tp.toggleDark(),
              ),
              SettingsChrome.switchTile(
                icon: Icons.apps_rounded,
                tint: const Color(0xFFFFE0D8),
                iconColor: ShellSurface.coral,
                title: '内页更多入口',
                subtitle: '详情播放右上角收纳图标，默认开启',
                value: sp.playerMoreButton,
                onChanged: sp.togglePlayerMoreButton,
              ),
              SettingsChrome.switchTile(
                icon: Icons.timer_outlined,
                tint: const Color(0xFFFFE8C8),
                iconColor: const Color(0xFFC47A12),
                title: '片尾倒计时切集',
                subtitle: '3 秒确认；关闭则直接下一集',
                value: sp.autoNextCountdown,
                onChanged: sp.toggleAutoNextCountdown,
              ),
            ],
          ),
          const SizedBox(height: ShellSurface.sectionGap),
          SettingsChrome.section(
            title: '合规与关于',
            children: [
              SettingsChrome.navTile(
                icon: Icons.child_care_rounded,
                tint: const Color(0xFFE8F7F4),
                iconColor: ShellSurface.accent,
                title: '青少年模式',
                subtitle: '限制付费与社交（一期占位）',
                onTap: () => _showYouthDialog(context),
              ),
              SettingsChrome.navTile(
                icon: Icons.flag_rounded,
                tint: const Color(0xFFFFE0D8),
                iconColor: ShellSurface.coral,
                title: '举报与反馈',
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已记录反馈入口'),
                    behavior: SnackBarBehavior.floating,
                  ),
                ),
              ),
              SettingsChrome.navTile(
                icon: Icons.info_rounded,
                tint: const Color(0xFFE8E6E2),
                iconColor: ShellSurface.muted,
                title: '关于 ZiTok',
                subtitle: '短剧 · v0.1.0',
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'ZiTok 短剧',
                  applicationVersion: '0.1.0',
                  applicationLegalese: '沉浸竖屏短剧体验',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showYouthDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ShellSurface.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('青少年模式', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          '一期占位：开启后将限制付费解锁与私信功能。',
          style: ShellSurface.caption.copyWith(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了', style: TextStyle(color: ShellSurface.coral, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Future<String?> _showLanguageSheet(BuildContext context, String current) {
    const langs = ['简体中文', 'English'];
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: ShellSurface.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
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
                    color: ShellSurface.ink.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 14),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('选择语言', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                const SizedBox(height: 8),
                for (final lang in langs)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(lang, style: ShellSurface.bodyStrong),
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
  @override
  Widget build(BuildContext context) {
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
                const Text(
                  '个性化你的短剧',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  '通知、播放手势与账户安全一站管理',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.62), fontSize: 12.5, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
