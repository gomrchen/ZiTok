import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../app.dart';
import '../../l10n/l10n_ext.dart';
import '../../services/user_service.dart';
import '../../providers/messaging_provider.dart';
import '../../utils/url_utils.dart';
import '../home/shell_surface.dart';

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
  String _statusText = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _executeSearch() async {
    final keyword = _searchCtrl.text.trim();
    if (keyword.isEmpty) return;
    if (!mounted) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _statusText = '';
      _userList = [];
    });

    final l10n = context.l10n;
    try {
      final api = UserService(AppBootstrap.apiClient.dio);
      final response = await api.searchRemoteUsers(keyword);
      final jsonMap = response.data;

      if (jsonMap['code'] == 10000 || jsonMap['code'] == '10000') {
        final List rawUsers = jsonMap['data']?['users'] ?? [];
        if (!mounted) return;
        final mp = context.read<MessagingProvider>();
        final followingIds = mp.following.map((e) => e.id).toSet();
        final parsedList = <SearchResultItem>[];

        for (final item in rawUsers) {
          try {
            final id = (item['user_id'] ?? '').toString();
            final name = (item['username'] ?? l10n.globalSearchUnknownUser).toString();
            final rawUrl = (item['avatar_url'] ?? '').toString();
            var finalUrl = '';
            if (rawUrl.isNotEmpty && rawUrl != 'null') {
              finalUrl = UrlUtils.resolveStorageUrl(rawUrl, defaultDir: 'avatars');
            }
            var isAdded = followingIds.contains(id);
            if (id == mp.currentUid.toString()) isAdded = true;
            parsedList.add(SearchResultItem(
              id: id,
              name: name,
              avatarUrl: finalUrl,
              isFollowed: isAdded,
            ));
          } catch (_) {}
        }

        if (mounted) {
          setState(() {
            _userList = parsedList;
            if (parsedList.isEmpty) _statusText = l10n.globalSearchNotFound;
          });
        }
      } else if (mounted) {
        setState(() => _statusText = (jsonMap['message'] as String?) ?? l10n.globalSearchFailed);
      }
    } catch (_) {
      if (mounted) setState(() => _statusText = l10n.globalSearchNetworkError);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ink = ShellSurface.inkOf(context);
    return AnnotatedRegion(
      value: ShellSurface.systemUiOf(context),
      child: Scaffold(
        backgroundColor: ShellSurface.canvasOf(context),
        appBar: ShellSurface.appBar(
          title: '',
          context: context,
          titleWidget: TextField(
            controller: _searchCtrl,
            autofocus: true,
            textInputAction: TextInputAction.search,
            style: TextStyle(color: ink, fontSize: 16, fontWeight: FontWeight.w600),
            cursorColor: ShellSurface.accent,
            decoration: InputDecoration(
              hintText: l10n.globalSearchHint,
              hintStyle: TextStyle(color: ink.withValues(alpha: 0.35)),
              border: InputBorder.none,
              isDense: true,
            ),
            onSubmitted: (_) => _executeSearch(),
          ),
          actions: [
            IconButton(
              tooltip: '搜索',
              icon: const Icon(Icons.search_rounded),
              onPressed: _executeSearch,
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final l10n = context.l10n;
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: ShellSurface.coral));
    }
    if (_userList.isEmpty) {
      return Center(
        child: Text(
          _statusText.isEmpty ? l10n.globalSearchEmpty : _statusText,
          style: ShellSurface.captionOf(context).copyWith(fontSize: 14),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _userList.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: ShellSurface.lineOf(context)),
      itemBuilder: (context, index) => _buildUserRow(_userList[index]),
    );
  }

  Widget _buildUserRow(SearchResultItem user) {
    final ink = ShellSurface.inkOf(context);
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: ClipOval(child: _buildAvatarImage(user)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.userIdLabel(user.id),
                  style: ShellSurface.captionOf(context),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 76,
            height: 32,
            child: user.isFollowed ? _buildFollowedButton() : _buildFollowButton(user),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarImage(SearchResultItem user) {
    if (user.avatarUrl.isEmpty) return _buildDefaultAvatar();
    return CachedNetworkImage(
      imageUrl: user.avatarUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => _buildDefaultAvatar(),
      errorWidget: (context, url, error) => _buildDefaultAvatar(),
    );
  }

  Widget _buildDefaultAvatar() {
    return ColoredBox(
      color: ShellSurface.isDark(context) ? const Color(0xFF1F2937) : const Color(0xFFF0EEEA),
      child: Icon(
        Icons.person_rounded,
        color: ShellSurface.mutedOf(context),
        size: 30,
      ),
    );
  }

  Widget _buildFollowedButton() {
    return FilledButton(
      onPressed: null,
      style: FilledButton.styleFrom(
        disabledBackgroundColor: ShellSurface.lineOf(context),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(
        context.l10n.globalSearchFollowed,
        style: TextStyle(fontSize: 12, color: ShellSurface.mutedOf(context)),
      ),
    );
  }

  Widget _buildFollowButton(SearchResultItem user) {
    return FilledButton(
      onPressed: () => _handleFollow(user),
      style: FilledButton.styleFrom(
        backgroundColor: ShellSurface.accent,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(context.l10n.globalSearchFollow, style: const TextStyle(fontSize: 12)),
    );
  }

  void _handleFollow(SearchResultItem user) {
    final remarkCtrl = TextEditingController();
    final l10n = context.l10n;
    final ink = ShellSurface.inkOf(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => ShellSurface.dialog(
        context: ctx,
        title: l10n.dialogFollowUser(user.name),
        content: TextField(
          controller: remarkCtrl,
          style: TextStyle(color: ink, fontSize: 15),
          decoration: InputDecoration(
            hintText: l10n.dialogFollowRemarkHint,
            hintStyle: TextStyle(color: ink.withValues(alpha: 0.35)),
            filled: true,
            fillColor: ShellSurface.canvasOf(ctx),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: ShellSurface.lineOf(ctx)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: ShellSurface.lineOf(ctx)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: ShellSurface.coral, width: 1.4),
            ),
          ),
        ),
        actions: [
          ShellSurface.cancelAction(
            ctx,
            onPressed: () => Navigator.pop(ctx),
            label: l10n.commonCancel,
          ),
          ShellSurface.confirmAction(
            onPressed: () {
              Navigator.pop(ctx);
              _performFollow(user, remarkCtrl.text);
            },
            label: l10n.commonConfirm,
            color: ShellSurface.accent,
          ),
        ],
      ),
    );
  }

  Future<void> _performFollow(SearchResultItem user, String remark) async {
    try {
      final mp = context.read<MessagingProvider>();
      final msg = await mp.addFriendAction(user.id, remark);
      if (!mounted) return;
      if (msg == 'OK') {
        setState(() => user.isFollowed = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.globalSearchFollowOk),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (_) {}
  }
}
