import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../app.dart';
import '../../services/user_service.dart';
import '../../providers/messaging_provider.dart';
import '../../utils/url_utils.dart'; // 【核心】引入项目中已有的 URL 工具类

// 数据模型
class SearchResultItem {
  final String id;
  final String name;
  final String avatarUrl;
  bool isFollowed;

  SearchResultItem({
    required this.id,
    required this.name,
    required this.avatarUrl,
    this.isFollowed = false,
  });
}

class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({super.key});

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<SearchResultItem> _userList = [];
  bool _isLoading = false;
  String _statusText = "";

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _executeSearch() async {
    final keyword = _searchCtrl.text.trim();
    if (keyword.isEmpty) return;

    if (!mounted) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _statusText = "";
      _userList = [];
    });

    try {
      final api = UserService(AppBootstrap.apiClient.dio);
      final response = await api.searchRemoteUsers(keyword);
      final jsonMap = response.data;

      if (jsonMap['code'] == 10000 || jsonMap['code'] == '10000') {
        final List rawUsers = jsonMap['data']?['users'] ?? [];

        if (!mounted) return;
        final mp = context.read<MessagingProvider>();
        // 获取关注列表用于比对状态
        final Set<String> followingIds = mp.following.map((e) => e.id).toSet();
        final List<SearchResultItem> parsedList = [];

        for (var item in rawUsers) {
          try {
            String id = (item['user_id'] ?? "").toString();
            String name = (item['username'] ?? "未知用户").toString();
            String rawUrl = (item['avatar_url'] ?? "").toString();

            // 【核心修改】使用 MessagingProvider 同款的解码逻辑
            // 直接调用项目中现成的 UrlUtils，自动处理 BaseURL 和静态资源路径
            String finalUrl = "";
            if (rawUrl.isNotEmpty && rawUrl != 'null') {
              // 这里的 defaultDir: 'avatars' 是参考 MessagingProvider 里的用法
              finalUrl = UrlUtils.resolveStorageUrl(rawUrl, defaultDir: 'avatars');
            }

            // 判断关注状态
            bool isAdded = followingIds.contains(id);
            if (id == mp.currentUid.toString()) isAdded = true;

            parsedList.add(SearchResultItem(
              id: id,
              name: name,
              avatarUrl: finalUrl,
              isFollowed: isAdded,
            ));
          } catch (e) {
            // Parsing error - skip this item
          }
        }

        if (mounted) {
          setState(() {
            _userList = parsedList;
            if (parsedList.isEmpty) _statusText = "未找到相关用户";
          });
        }
      } else {
        if (mounted) setState(() => _statusText = jsonMap['message'] ?? "搜索失败");
      }
    } catch (e) {
      if (mounted) setState(() => _statusText = "网络错误");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: TextField(
          controller: _searchCtrl,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: "搜索全网用户...",
            border: InputBorder.none,
          ),
          onSubmitted: (_) => _executeSearch(),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: _executeSearch)
        ],
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_userList.isEmpty) {
      return Center(
        child: Text(
          _statusText.isEmpty ? "搜索用户 ID 或昵称" : _statusText,
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 10),
      itemCount: _userList.length,
      itemBuilder: (context, index) {
        return _buildUserRow(_userList[index]);
      },
    );
  }

  Widget _buildUserRow(SearchResultItem user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // 头像区域
          SizedBox(
            width: 52,
            height: 52,
            child: ClipOval(
              child: _buildAvatarImage(user),
            ),
          ),

          const SizedBox(width: 14),

          // 文本区域
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "ID: ${user.id}",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),

          // 按钮区域
          SizedBox(
            width: 72,
            height: 32,
            child: user.isFollowed
                ? _buildFollowedButton()
                : _buildFollowButton(user),
          ),
        ],
      ),
    );
  }

  // 构建头像 (使用 CachedNetworkImage 确保稳健性)
  Widget _buildAvatarImage(SearchResultItem user) {
    if (user.avatarUrl.isEmpty) {
      return _buildDefaultAvatar();
    }

    return CachedNetworkImage(
      imageUrl: user.avatarUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: Colors.grey.shade100,
        child: const Icon(Icons.person, color: Colors.grey),
      ),
      errorWidget: (context, url, error) {
        // 如果 UrlUtils 解析出来的地址依然有问题，这里会兜底显示默认图
        return _buildDefaultAvatar();
      },
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: Colors.grey.shade100,
      child: const Icon(Icons.person, color: Colors.grey, size: 30),
    );
  }

  Widget _buildFollowedButton() {
    return FilledButton(
      onPressed: null,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.grey[300],
        disabledBackgroundColor: Colors.grey[300],
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: const Text("已关注", style: TextStyle(fontSize: 12, color: Colors.white)),
    );
  }

  Widget _buildFollowButton(SearchResultItem user) {
    return FilledButton(
      onPressed: () => _handleFollow(user),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF26D5B1),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: const Text("关注", style: TextStyle(fontSize: 12)),
    );
  }

  void _handleFollow(SearchResultItem user) {
    final remarkCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("关注 ${user.name}"),
        content: TextField(
          controller: remarkCtrl,
          decoration: const InputDecoration(
            hintText: "设置备注 (选填)",
            border: UnderlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("取消", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _performFollow(user, remarkCtrl.text);
            },
            child: const Text("确定", style: TextStyle(color: Color(0xFF26D5B1))),
          ),
        ],
      ),
    );
  }

  Future<void> _performFollow(SearchResultItem user, String remark) async {
    try {
      final mp = context.read<MessagingProvider>();
      final msg = await mp.addFriendAction(user.id, remark);

      if (mounted) {
        if (msg == "OK") {
          setState(() {
            user.isFollowed = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("关注成功"), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      // Follow action failed
    }
  }
}
