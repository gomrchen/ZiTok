import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../theme/theme_tokens.dart';
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
    final TextEditingController usernameController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加账号'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(labelText: '用户名'),
              autofocus: true,
            ),
            const SizedBox(height: Spacing.md),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: '密码'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              if (usernameController.text.isNotEmpty &&
                  passwordController.text.isNotEmpty) {
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('请输入用户名和密码')));
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() {
        _accounts.add(
          AccountEntry(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            username: usernameController.text,
            password: passwordController.text,
          ),
        );
      });
      await _saveAccounts();
    }

    usernameController.dispose();
    passwordController.dispose();
  }

  Future<void> _deleteAccount(String id) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除账号'),
        content: const Text('确定要删除这个账号吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
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
    return Scaffold(
      appBar: AppBar(title: const Text('切换账号')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _accounts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('暂无保存的账号'),
                  const SizedBox(height: Spacing.md),
                  ElevatedButton(
                    onPressed: _addAccount,
                    child: const Text('添加账号'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(Spacing.md),
              itemCount: _accounts.length,
              itemBuilder: (context, index) {
                final account = _accounts[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: Spacing.md),
                  child: ListTile(
                    title: Text(account.username),
                    subtitle: Text('密码: ${_maskPassword(account.password)}'),
                    // 切换账号功能已移至右侧按钮
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.switch_account_outlined),
                          onPressed: () => _switchToAccount(context, account),
                          color: Colors.blue,
                          tooltip: '切换到此账号',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteAccount(account.id),
                          color: Colors.red,
                          tooltip: '删除账号',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addAccount,
        tooltip: '添加账号',
        child: const Icon(Icons.add),
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

    log('开始切换账号: ${account.username}');
    log('切换前登录状态: ${authProvider.isAuthenticated}');

    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: Spacing.md),
            Text('正在切换账号...'),
          ],
        ),
      ),
    );

    try {
      // 先登出当前账号
      log('执行登出操作');
      await authProvider.logout();

      // 验证登出是否成功
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      log('登出后验证: token = $token');
      log('登出后登录状态: ${authProvider.isAuthenticated}');

      // 延迟一小段时间，确保登出操作完成
      await Future.delayed(const Duration(milliseconds: 500));

      // 使用保存的凭证登录新账号
      log('执行登录操作: ${account.username}');
      await authProvider.login(account.username, account.password);

      // 验证登录是否成功
      final newToken = prefs.getString('access_token');
      log('登录后验证: token = $newToken');
      log('登录后登录状态: ${authProvider.isAuthenticated}');

      // 登录成功后，关闭所有页面并导航到主页
      if (context.mounted) {
        Navigator.of(context).pop(); // 关闭加载对话框
        // 使用go_router导航，替换Navigator.pushNamedAndRemoveUntil
        context.go('/home');
        log('账号切换成功，导航到主页');
      }
    } catch (e) {
      log('账号切换失败: $e');
      if (context.mounted) {
        Navigator.of(context).pop(); // 关闭加载对话框
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('切换账号失败: ${e.toString()}')));
      }
    }
  }
}
