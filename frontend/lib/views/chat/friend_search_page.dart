import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/messaging_provider.dart';
import '../home/shell_surface.dart';
import 'chat_page.dart';
import '../../models/social_models.dart';

class FriendSearchPage extends StatefulWidget {
  const FriendSearchPage({super.key});

  @override
  State<FriendSearchPage> createState() => _FriendSearchPageState();
}

class _FriendSearchPageState extends State<FriendSearchPage> {
  final TextEditingController _searchCtrl = TextEditingController();

  // 用于存储搜索结果的本地列表
  List<Conversation> _searchResults = [];
  String _keyword = "";

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // 核心逻辑：本地搜索
  void _onSearchChanged(String query) {
    final cleanQuery = query.trim().toLowerCase();
    _keyword = cleanQuery;

    if (cleanQuery.isEmpty) {
      if (mounted) setState(() => _searchResults = []);
      return;
    }

    // 1. 获取 Provider 里的全量本地数据 (关注 + 粉丝 + 群聊)
    final mp = context.read<MessagingProvider>();
    final allData = mp.allConversations;

    // 2. 简单的内存过滤
    final results = allData.where((item) {
      // 安全获取属性，防止 null
      final name = item.name.toLowerCase();
      final id = item.id;

      // 模糊匹配：名字包含 OR ID包含
      return name.contains(cleanQuery) || id.contains(cleanQuery);
    }).toList();

    if (mounted) {
      setState(() {
        _searchResults = results;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: ShellSurface.canvasOf(context),
      appBar: ShellSurface.appBar(
        title: '',
        context: context,
        titleWidget: TextField(
          controller: _searchCtrl,
          autofocus: true,
          onChanged: _onSearchChanged,
          style: textTheme.bodyLarge?.copyWith(color: ShellSurface.inkOf(context)),
          decoration: InputDecoration(
            hintText: '搜索本地好友 / ID...',
            border: InputBorder.none,
            isDense: true,
            hintStyle: textTheme.bodyLarge?.copyWith(
              color: ShellSurface.mutedOf(context),
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: '关闭',
            icon: Icon(Icons.close_rounded, color: ShellSurface.inkOf(context)),
            onPressed: () {
              _searchCtrl.clear();
              _onSearchChanged('');
              Navigator.pop(context);
            },
          )
        ],
      ),
      body: _buildList(),
    );
  }

  Widget _buildList() {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // 1. 没输入时的提示
    if (_keyword.isEmpty) {
      return Center(
        child: Text(
          "输入关键词搜索已关注的好友",
          style: textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      );
    }

    // 2. 搜不到结果
    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          "未找到匹配用户",
          style: textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      );
    }

    // 3. 渲染列表
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final item = _searchResults[index];
        return _buildSafeTile(item);
      },
    );
  }

  // 一个绝对安全的 Tile 构建方法
  Widget _buildSafeTile(Conversation item) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // 1. 提取数据
    final safeName = item.name;
    final safeId = item.id;
    final avatarUrl = item.avatarUrl;
    final isGroup = item.isGroup;

    // 2. 简单的头像校验
    bool showImage = false;
    if (avatarUrl.isNotEmpty && avatarUrl != "null" && avatarUrl.startsWith("http")) {
      showImage = true;
    }

    return ListTile(
      // 加上 Key 防止渲染混淆 (解决 Assertion failed)
      key: ValueKey("search_item_$safeId"),

      leading: CircleAvatar(
        radius: 24,
        backgroundColor: cs.surfaceContainerHighest,
        // 如果图片地址有效，显示图片；否则显示 null 让它走 child 逻辑
        backgroundImage: showImage
            ? CachedNetworkImageProvider(avatarUrl)
            : null,
        // 如果没图，显示一个默认 Icon
        child: !showImage
            ? Icon(isGroup ? Icons.group : Icons.person, color: cs.onSurfaceVariant)
            : null,
      ),

      title: Text(
        safeName,
        style: textTheme.bodyLarge?.copyWith(color: cs.onSurface),
      ),
      subtitle: Text(
        isGroup ? "群聊" : "ID: $safeId",
        style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),

      // 点击跳转聊天
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChatPage(conversationId: safeId, isGroup: isGroup),
          ),
        );
      },
    );
  }
}
