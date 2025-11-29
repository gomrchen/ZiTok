import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/messaging_provider.dart';
import '../../models/social_models.dart'; // 确保引入了 Friend 模型

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final TextEditingController _nameCtrl = TextEditingController();

  // 选中的用户 ID 集合
  final Set<int> _selectedIds = {};

  // 候选人列表 (合并关注和粉丝)
  List<Friend> _candidates = [];

  @override
  void initState() {
    super.initState();
    // 初始化时加载候选人
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mp = context.read<MessagingProvider>();
      // 简单去重逻辑：将关注列表和粉丝列表合并
      final Map<String, Friend> uniqueMap = {};
      for (var f in mp.following) {
        uniqueMap[f.id] = f;
      }
      for (var f in mp.followers) {
        uniqueMap[f.id] = f;
      }

      setState(() {
        _candidates = uniqueMap.values.toList();
      });
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("请输入群名称")));
      return;
    }
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("请至少选择一个成员")));
      return;
    }

    // 调用 Provider 创建
    final mp = context.read<MessagingProvider>();
    final msg = await mp.createGroupAction(name, _selectedIds.toList());

    if (!mounted) return;

    if (msg == "OK") {
      Navigator.pop(context); // 关闭页面
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("群聊创建成功")));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("创建失败: $msg")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("发起群聊"),
        actions: [
          TextButton(
            onPressed: _submit,
            child: const Text("创建", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: Column(
        children: [
          // 1. 群名输入框
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: "群聊名称",
                hintText: "例如：周末开黑群",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.group_add),
              ),
            ),
          ),

          const Divider(height: 1),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("选择成员 (${_selectedIds.length})", style: TextStyle(color: Colors.grey[600])),
            ),
          ),

          // 2. 好友选择列表
          Expanded(
            child: _candidates.isEmpty
                ? const Center(child: Text("暂无互关好友可选"))
                : ListView.builder(
              itemCount: _candidates.length,
              itemBuilder: (context, index) {
                final friend = _candidates[index];
                final int fid = int.tryParse(friend.id) ?? 0;
                final bool isSelected = _selectedIds.contains(fid);

                return CheckboxListTile(
                  value: isSelected,
                  activeColor: Theme.of(context).primaryColor,
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        _selectedIds.add(fid);
                      } else {
                        _selectedIds.remove(fid);
                      }
                    });
                  },
                  secondary: CircleAvatar(
                    backgroundImage: (friend.avatarUrl.isNotEmpty)
                        ? CachedNetworkImageProvider(friend.avatarUrl)
                        : null,
                    child: friend.avatarUrl.isEmpty ? const Icon(Icons.person) : null,
                  ),
                  title: Text(friend.name),
                  subtitle: Text("ID: ${friend.id}"),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
