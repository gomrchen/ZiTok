import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/l10n_ext.dart';
import '../../providers/auth_provider.dart';
import '../../utils/error_handler.dart';
import '../home/shell_surface.dart';
import 'settings_chrome.dart';

class AccountSwitcherPage extends StatefulWidget {
  const AccountSwitcherPage({super.key});

  @override
  State<AccountSwitcherPage> createState() => _AccountSwitcherPageState();
}

class AccountEntry {
  final String id;
  final String username;
  final String password;

  AccountEntry({
    required this.id,
    required this.username,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'password': password,
      };

  factory AccountEntry.fromJson(Map<String, dynamic> json) => AccountEntry(
        id: json['id'],
        username: json['username'],
        password: json['password'],
      );
}

class _AccountSwitcherPageState extends State<AccountSwitcherPage> {
  List<AccountEntry> _accounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accountsJson = prefs.getString('saved_accounts');
      log('加载账号列表: accountsJson = $accountsJson');
      if (accountsJson != null) {
        final List<dynamic> accountsList = jsonDecode(accountsJson);
        setState(() {
          _accounts = accountsList.map((e) => AccountEntry.fromJson(e)).toList();
        });
      }
    } catch (e) {
      log('加载账号列表失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accountsJson = jsonEncode(_accounts.map((e) => e.toJson()).toList());
      await prefs.setString('saved_accounts', accountsJson);
    } catch (e) {
      log('保存账号列表失败: $e');
    }
  }

  Future<void> _addAccount() async {
    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (_) => const _AddAccountDialog(),
    );
    if (result == null || !mounted) return;
    setState(() {
      _accounts.add(
        AccountEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          username: result['username']!,
          password: result['password']!,
        ),
      );
    });
    await _saveAccounts();
  }

  Future<void> _deleteAccount(String id) async {
    final l10n = context.l10n;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => SettingsChrome.dialog(
        context: ctx,
        title: l10n.settingsDeleteAccount,
        content: Text(
          l10n.settingsDeleteAccountConfirm,
          style: ShellSurface.captionOf(ctx).copyWith(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              l10n.commonCancel,
              style: TextStyle(color: ShellSurface.inkOf(ctx).withValues(alpha: 0.55)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: ShellSurface.coral),
            child: Text(
              l10n.settingsDelete,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
    if (result != true || !mounted) return;
    setState(() => _accounts.removeWhere((account) => account.id == id));
    await _saveAccounts();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SettingsChrome.page(
      title: l10n.settingsSwitchTitle,
      actions: [
        IconButton(
          onPressed: _addAccount,
          tooltip: l10n.settingsAddAccount,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: ShellSurface.coral))
          : _accounts.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(ShellSurface.pagePad),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.switch_account_rounded,
                          size: 42,
                          color: ShellSurface.inkOf(context).withValues(alpha: 0.28),
                        ),
                        const SizedBox(height: 12),
                        Text(l10n.settingsNoSavedAccounts, style: ShellSurface.bodyStrongOf(context)),
                        const SizedBox(height: 6),
                        Text(l10n.settingsNoSavedAccountsHint, style: ShellSurface.captionOf(context)),
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: _addAccount,
                          style: SettingsChrome.primaryButton.copyWith(
                            minimumSize: const WidgetStatePropertyAll(Size(160, 46)),
                          ),
                          child: Text(l10n.settingsAddAccount),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    ShellSurface.pagePad,
                    8,
                    ShellSurface.pagePad,
                    28,
                  ),
                  itemCount: _accounts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final account = _accounts[index];
                    return Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                      decoration: BoxDecoration(
                        color: ShellSurface.cardOf(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: ShellSurface.lineOf(context)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: ShellSurface.isDark(context)
                                  ? const Color(0xFF1E3A5F)
                                  : const Color(0xFFE8F0FF),
                            ),
                            child: Icon(
                              Icons.person_rounded,
                              color: ShellSurface.isDark(context)
                                  ? const Color(0xFF93C5FD)
                                  : const Color(0xFF3B6FD9),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  account.username,
                                  style: ShellSurface.bodyStrongOf(context).copyWith(fontSize: 15),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  l10n.settingsPasswordMasked(_maskPassword(account.password)),
                                  style: ShellSurface.captionOf(context),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: l10n.settingsSwitchToAccount,
                            onPressed: () => _switchToAccount(account),
                            icon: const Icon(Icons.login_rounded, color: ShellSurface.accent),
                          ),
                          IconButton(
                            tooltip: l10n.settingsDeleteAccount,
                            onPressed: () => _deleteAccount(account.id),
                            icon: const Icon(Icons.delete_outline_rounded, color: ShellSurface.coral),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  String _maskPassword(String password) => '*' * password.length;

  Future<void> _switchToAccount(AccountEntry account) async {
    final authProvider = context.read<AuthProvider>();
    final router = GoRouter.of(context);
    final l10n = context.l10n;
    final navigator = Navigator.of(context);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: SettingsChrome.dialog(
          context: dialogContext,
          title: l10n.settingsSwitchTitle,
          content: Row(
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: ShellSurface.coral),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  l10n.settingsSwitchingAccount,
                  style: ShellSurface.bodyStrongOf(dialogContext),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      await authProvider.logout();
      await Future.delayed(const Duration(milliseconds: 500));
      await authProvider.login(account.username, account.password);
      if (!mounted) return;
      navigator.pop();
      router.go('/home');
    } catch (e) {
      log('账号切换失败: $e');
      if (!mounted) return;
      navigator.pop();
      if (!mounted) return;
      ErrorHandler.showError(context, e, prefix: l10n.settingsSwitchFailed);
    }
  }
}

class _AddAccountDialog extends StatefulWidget {
  const _AddAccountDialog();

  @override
  State<_AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends State<_AddAccountDialog> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = context.l10n;
    if (_usernameController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.loginNeedCredentials), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    Navigator.pop(context, {
      'username': _usernameController.text.trim(),
      'password': _passwordController.text,
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ink = ShellSurface.inkOf(context);
    return SettingsChrome.dialog(
      context: context,
      title: l10n.settingsAddAccount,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _usernameController,
            style: TextStyle(color: ink, fontSize: 15),
            decoration: SettingsChrome.fieldDecoration(
              context: context,
              label: l10n.loginUsername,
            ),
            autofocus: true,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            style: TextStyle(color: ink, fontSize: 15),
            decoration: SettingsChrome.fieldDecoration(
              context: context,
              label: l10n.loginPassword,
            ),
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(
            l10n.commonCancel,
            style: TextStyle(color: ink.withValues(alpha: 0.55)),
          ),
        ),
        TextButton(
          onPressed: _submit,
          style: TextButton.styleFrom(foregroundColor: ShellSurface.coral),
          child: Text(
            l10n.commonConfirm,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
