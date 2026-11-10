import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../services/user_session.dart';
import '../../utils/error_handler.dart';
import '../home/shell_surface.dart';
import 'settings_chrome.dart';
import 'dart:convert';
import 'dart:developer';

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
          _accounts = accountsList
              .map((e) => AccountEntry.fromJson(e))
              .toList();
        });
        log('成功加载 ${_accounts.length} 个账号');
      } else {
        log('账号列表为空');
      }
    } catch (e) {
      log('加载账号列表失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accountsJson = jsonEncode(
        _accounts.map((e) => e.toJson()).toList(),
      );
      await prefs.setString('saved_accounts', accountsJson);
      log('成功保存账号列表，共 ${_accounts.length} 个账号');

      // 验证保存是否成功
      final savedJson = prefs.getString('saved_accounts');
      if (savedJson != null) {
        final savedList = jsonDecode(savedJson) as List;
        log('验证保存成功，读取到 ${savedList.length} 个账号');
      }
    } catch (e) {
      log('保存账号列表失败: $e');
    }
  }

  Future<void> _addAccount() async {
    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (dialogContext) => const _AddAccountDialog(),
    );

    if (result != null) {
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
  }

  Future<void> _deleteAccount(String id) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ShellSurface.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('删除账号', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('确定要删除这个账号吗？', style: ShellSurface.caption.copyWith(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消', style: TextStyle(color: ShellSurface.ink.withValues(alpha: 0.55))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: ShellSurface.coral),
            child: const Text('删除', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() {
        _accounts.removeWhere((account) => account.id == id);
      });
      await _saveAccounts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsChrome.page(
      title: '切换账号',
      actions: [
        IconButton(
          onPressed: _addAccount,
          tooltip: '添加账号',
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
                        Icon(Icons.switch_account_rounded, size: 42, color: ShellSurface.ink.withValues(alpha: 0.28)),
                        const SizedBox(height: 12),
                        Text('暂无保存的账号', style: ShellSurface.bodyStrong),
                        const SizedBox(height: 6),
                        Text('添加后可一键切换登录', style: ShellSurface.caption),
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: _addAccount,
                          style: SettingsChrome.primaryButton.copyWith(
                            minimumSize: const WidgetStatePropertyAll(Size(160, 46)),
                          ),
                          child: const Text('添加账号'),
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
                        color: ShellSurface.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: ShellSurface.line),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: const Color(0xFFE8F0FF),
                            ),
                            child: const Icon(Icons.person_rounded, color: Color(0xFF3B6FD9)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(account.username, style: ShellSurface.bodyStrong.copyWith(fontSize: 15)),
                                const SizedBox(height: 3),
                                Text('密码 ${_maskPassword(account.password)}', style: ShellSurface.caption),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: '切换到此账号',
                            onPressed: () => _switchToAccount(context, account),
                            icon: const Icon(Icons.login_rounded, color: ShellSurface.accent),
                          ),
                          IconButton(
                            tooltip: '删除账号',
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

  String _maskPassword(String password) {
    return '*' * password.length;
  }

  //切换到指定账号
  Future<void> _switchToAccount(
    BuildContext context,
    AccountEntry account,
  ) async {
    final authProvider = context.read<AuthProvider>();
    final router = GoRouter.of(context);

    log('开始切换账号: ${account.username}');
    log('切换前登录状态: ${authProvider.isAuthenticated}');

    // 显示加载对话框，保存 Navigator 用于后续关闭
    final navigator = Navigator.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: ShellSurface.card,
          content: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: ShellSurface.coral),
              ),
              SizedBox(width: 14),
              Text('正在切换账号...', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );

    try {
      // 先登出当前账号
      log('执行登出操作');
      await authProvider.logout();

      // 验证登出是否成功（统一从 UserSession 获取）
      final userSession = UserSession.instance;
      log('登出后验证: token = ${userSession.accessToken}');
      log('登出后登录状态: ${authProvider.isAuthenticated}');

      // 延迟一小段时间，确保登出操作完成
      await Future.delayed(const Duration(milliseconds: 500));

      // 使用保存的凭证登录新账号
      log('执行登录操作: ${account.username}');
      await authProvider.login(account.username, account.password);

      // 验证登录是否成功（统一从 UserSession 获取）
      log('登录后验证: token = ${userSession.accessToken}');
      log('登录后登录状态: ${authProvider.isAuthenticated}');

      // 登录成功后，关闭所有页面并导航到主页
      if (mounted) {
        navigator.pop(); // 关闭加载对话框
        // 使用go_router导航，替换Navigator.pushNamedAndRemoveUntil
        router.go('/home');
        log('账号切换成功，导航到主页');
      }
    } catch (e) {
      log('账号切换失败: $e');
      if (mounted) {
        navigator.pop(); // 关闭加载对话框
        if (context.mounted) {
          ErrorHandler.showError(context, e, prefix: '切换账号失败');
        }
      }
    }
  }
}

/// 添加账号对话框 - 独立 StatefulWidget 管理控制器生命周期
class _AddAccountDialog extends StatefulWidget {
  const _AddAccountDialog();

  @override
  State<_AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends State<_AddAccountDialog> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_usernameController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty) {
      Navigator.pop(context, {
        'username': _usernameController.text,
        'password': _passwordController.text,
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入用户名和密码')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: ShellSurface.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('添加账号', style: TextStyle(fontWeight: FontWeight.w800)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _usernameController,
            decoration: SettingsChrome.fieldDecoration(label: '用户名'),
            autofocus: true,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            decoration: SettingsChrome.fieldDecoration(label: '密码'),
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text('取消', style: TextStyle(color: ShellSurface.ink.withValues(alpha: 0.55))),
        ),
        TextButton(
          onPressed: _submit,
          style: TextButton.styleFrom(foregroundColor: ShellSurface.coral),
          child: const Text('确定', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}
