import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:lpinyin/lpinyin.dart';
import '../../models/social_models.dart';
import '../../repositories/relation_repository.dart';
import '../../services/relation_service.dart';
import '../../app.dart';
import '../../utils/url_utils.dart';
import '../../theme/theme_tokens.dart';
import '../home/shell_surface.dart';

/// 群成员信息（扩展Friend，包含角色）
class GroupMember {
  final Friend friend;
  final bool isCreator;
  final bool isAdmin;
  final String pinyin; // 拼音首字母

  GroupMember({
    required this.friend,
    this.isCreator = false,
    this.isAdmin = false,
  }) : pinyin = _getPinyinInitial(friend.name);

  static String _getPinyinInitial(String name) {
    if (name.isEmpty) return '#';
    final first = name[0];
    // 检查是否是字母
    if (RegExp(r'[a-zA-Z]').hasMatch(first)) {
      return first.toUpperCase();
    }
    // 尝试转换中文为拼音
    try {
      final py = PinyinHelper.getFirstWordPinyin(first);
      if (py.isNotEmpty && RegExp(r'[a-zA-Z]').hasMatch(py[0])) {
        return py[0].toUpperCase();
      }
    } catch (_) {}
    return '#';
  }

  String get id => friend.id;
  String get name => friend.name;
  String get avatarUrl => friend.avatarUrl;
}

/// 群聊成员页面
class GroupMembersPage extends StatefulWidget {
  final String roomId;
  final String groupName;

  const GroupMembersPage({
    super.key,
    required this.roomId,
    required this.groupName,
  });

  @override
  State<GroupMembersPage> createState() => _GroupMembersPageState();
}

class _GroupMembersPageState extends State<GroupMembersPage> {
  List<GroupMember> _members = [];
  List<GroupMember> _filteredMembers = [];
  bool _loading = true;
  String? _error;
  int _creatorId = 0;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // 按首字母分组的数据
  Map<String, List<GroupMember>> _groupedMembers = {};
  List<String> _sortedKeys = [];

  // 字母索引
  static const List<String> _alphabetIndex = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '#'
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadMembers();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _filterMembers(_searchController.text);
  }

  void _filterMembers(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      _filteredMembers = List.from(_members);
    } else {
      _filteredMembers = _members.where((m) {
        return m.name.toLowerCase().contains(q) ||
            m.id.contains(q) ||
            m.pinyin.toLowerCase().startsWith(q);
      }).toList();
    }
    _groupMembers();
    setState(() {});
  }

  void _groupMembers() {
    _groupedMembers = {};

    // 先分离群主和管理员
    final admins = _filteredMembers.where((m) => m.isCreator || m.isAdmin).toList();
    final normalMembers = _filteredMembers.where((m) => !m.isCreator && !m.isAdmin).toList();

    // 管理员组（如果有）
    if (admins.isNotEmpty) {
      _groupedMembers['★'] = admins;
    }

    // 普通成员按首字母分组
    for (final m in normalMembers) {
      final key = m.pinyin;
      _groupedMembers.putIfAbsent(key, () => []).add(m);
    }

    // 排序keys，★在最前面
    _sortedKeys = _groupedMembers.keys.toList();
    _sortedKeys.sort((a, b) {
      if (a == '★') return -1;
      if (b == '★') return 1;
      if (a == '#') return 1;
      if (b == '#') return -1;
      return a.compareTo(b);
    });
  }

  Future<void> _loadMembers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final relationService = RelationService(AppBootstrap.apiClient.dio);
      final relationRepo = RelationRepository(api: relationService);

      // 获取群成员ID列表
      final roomId = int.tryParse(widget.roomId) ?? 0;
      final userId = int.tryParse(AppBootstrap.userSession.userId ?? '') ?? 0;
      if (userId <= 0) {
        throw Exception('请先登录');
      }
      final result = await relationRepo.getChatRoomMembers(roomId, userId: userId);

      if (result['success'] != true) {
        throw Exception('获取群成员失败');
      }

      final List<int> memberIds = List<int>.from(result['member_ids'] ?? []);
      _creatorId = result['creator_id'] ?? 0;

      if (memberIds.isEmpty) {
        setState(() {
          _loading = false;
          _members = [];
          _filteredMembers = [];
          _groupMembers();
        });
        return;
      }

      // 批量获取用户信息
      final friends = await relationRepo.getUsersByIds(memberIds);

      // 转换为GroupMember
      _members = friends.map((f) {
        final uid = int.tryParse(f.id) ?? 0;
        return GroupMember(
          friend: f,
          isCreator: uid == _creatorId,
          isAdmin: false, // 暂无管理员信息，可后续扩展
        );
      }).toList();

      // 排序：群主在前，然后按拼音排序
      _members.sort((a, b) {
        if (a.isCreator) return -1;
        if (b.isCreator) return 1;
        if (a.isAdmin && !b.isAdmin) return -1;
        if (!a.isAdmin && b.isAdmin) return 1;
        return a.pinyin.compareTo(b.pinyin);
      });

      _filteredMembers = List.from(_members);
      _groupMembers();

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _scrollToLetter(String letter) {
    // 查找该字母对应的位置
    if (!_groupedMembers.containsKey(letter)) return;

    double offset = 0;
    for (final key in _sortedKeys) {
      if (key == letter) break;
      // 计算每个分组的高度：标题 + 成员数 * 单项高度
      offset += 36; // 分组标题高度
      offset += (_groupedMembers[key]?.length ?? 0) * 64; // 每个成员项高度
    }

    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: ShellSurface.canvasOf(context),
      appBar: ShellSurface.appBar(
        title: '群聊成员',
        context: context,
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '群聊成员',
              style: TextStyle(
                color: ShellSurface.inkOf(context),
                fontWeight: FontWeight.w800,
                fontSize: 17,
                letterSpacing: 0.3,
              ),
            ),
            Text(
              '共${_members.length}人',
              style: TextStyle(
                color: ShellSurface.mutedOf(context),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildContent(theme, cs),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: Spacing.md),
          Text(_error ?? '加载失败'),
          const SizedBox(height: Spacing.md),
          ElevatedButton(onPressed: _loadMembers, child: const Text('重试')),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme, ColorScheme cs) {
    return Column(
      children: [
        // 搜索框
        Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索成员',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: cs.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              isDense: true,
            ),
          ),
        ),

        // 成员列表
        Expanded(
          child: _filteredMembers.isEmpty
              ? Center(
                  child: Text(
                    _searchController.text.isNotEmpty ? '未找到匹配的成员' : '暂无成员',
                    style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                )
              : Row(
                  children: [
                    // 主列表
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: Spacing.xl),
                        itemCount: _sortedKeys.length,
                        itemBuilder: (context, index) {
                          final key = _sortedKeys[index];
                          final members = _groupedMembers[key] ?? [];
                          return _buildGroup(key, members, theme, cs);
                        },
                      ),
                    ),

                    // 字母索引栏
                    _buildAlphabetIndex(cs),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildGroup(String key, List<GroupMember> members, ThemeData theme, ColorScheme cs) {
    final title = key == '★' ? '群主、管理员(${members.length}人)' : '$key(${members.length}人)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分组标题
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
          color: cs.surfaceContainerLow,
          child: Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        // 成员列表
        ...members.map((m) => _buildMemberTile(m, theme, cs)),
      ],
    );
  }

  Widget _buildMemberTile(GroupMember member, ThemeData theme, ColorScheme cs) {
    return InkWell(
      onTap: () => context.push('/user/${member.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
        child: Row(
          children: [
            // 头像
            GestureDetector(
              onTap: () => context.push('/user/${member.id}'),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: cs.primaryContainer,
                backgroundImage: member.avatarUrl.isNotEmpty
                    ? CachedNetworkImageProvider(
                        UrlUtils.resolveStorageUrl(member.avatarUrl, defaultDir: 'avatars'),
                      )
                    : null,
                child: member.avatarUrl.isEmpty
                    ? Text(
                        member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                        style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: Spacing.md),

            // 角色标签和名称
            Expanded(
              child: Row(
                children: [
                  // 角色标签
                  if (member.isCreator)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B6B),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '群主',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
                      ),
                    )
                  else if (member.isAdmin)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '管理员',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
                      ),
                    ),

                  // 名称
                  Expanded(
                    child: Text(
                      member.name,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // 添加好友按钮（暂时隐藏，可后续实现）
            // OutlinedButton(
            //   onPressed: () {},
            //   style: OutlinedButton.styleFrom(
            //     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            //     minimumSize: Size.zero,
            //     tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            //   ),
            //   child: const Text('添加'),
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlphabetIndex(ColorScheme cs) {
    return Container(
      width: 24,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _alphabetIndex.map((letter) {
          final hasMembers = _groupedMembers.containsKey(letter);
          return GestureDetector(
            onTap: hasMembers ? () => _scrollToLetter(letter) : null,
            child: Container(
              height: 18,
              alignment: Alignment.center,
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: 10,
                  color: hasMembers ? cs.primary : cs.onSurfaceVariant.withValues(alpha: 0.4),
                  fontWeight: hasMembers ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
