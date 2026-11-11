import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../l10n/l10n_ext.dart';
import '../../theme/theme_tokens.dart';
import '../../services/search_history_service.dart';
import '../home/shell_surface.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  SearchHistoryService? _historyService;
  List<String> _searchHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initHistoryService();
    // 自动聚焦搜索框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  Future<void> _initHistoryService() async {
    final prefs = await SharedPreferences.getInstance();
    _historyService = SearchHistoryService(prefs);
    _loadHistory();
  }

  void _loadHistory() {
    if (_historyService != null) {
      setState(() {
        _searchHistory = _historyService!.getHistory();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _handleSearch([String? keyword]) {
    String query = keyword ?? _searchController.text.trim();
    if (query.isNotEmpty) {
      // 保存搜索历史
      _historyService?.addHistory(query).then((_) => _loadHistory());
      // 导航到搜索结果页面
      context.push('/search/results?keywords=$query');
    }
  }

  void _handleBack() {
    context.pop();
  }

  Future<void> _clearHistory() async {
    final l10n = context.l10n;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return ShellSurface.dialog(
          context: ctx,
          title: l10n.dialogClearSearchHistory,
          content: Text(l10n.dialogClearSearchHistoryBody),
          actions: [
            ShellSurface.cancelAction(
              ctx,
              onPressed: () => Navigator.pop(ctx, false),
              label: l10n.commonCancel,
            ),
            ShellSurface.confirmAction(
              onPressed: () => Navigator.pop(ctx, true),
              label: l10n.commonConfirm,
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _historyService?.clearHistory();
      _loadHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.dialogSearchHistoryCleared),
            duration: const Duration(milliseconds: 1500),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _removeHistoryItem(String keyword) async {
    await _historyService?.removeHistory(keyword);
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部搜索栏
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.sm,
              ),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: cs.surfaceContainerHighest),
                ),
              ),
              child: Row(
                children: [
                  ShellSurface.backButton(context, onPressed: _handleBack),
                  const SizedBox(width: Spacing.sm),
                  // 搜索输入框
                  Expanded(
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search,
                            size: 18,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: Spacing.xs),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              textAlignVertical: TextAlignVertical.center,
                              decoration: InputDecoration(
                                hintText: '搜索视频、用户或话题',
                                hintStyle: textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                isDense: true,
                              ),
                              style: textTheme.bodyMedium?.copyWith(
                                color: cs.onSurface,
                              ),
                              onSubmitted: (_) => _handleSearch(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 搜索按钮
                  Padding(
                    padding: const EdgeInsets.only(left: Spacing.sm),
                    child: TextButton(
                      onPressed: () => _handleSearch(),
                      child: Text(
                        '搜索',
                        style: textTheme.bodyMedium?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 搜索历史区域
            Expanded(
              child: _buildHistorySection(cs, textTheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection(ColorScheme cs, TextTheme textTheme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题栏
        Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '搜索历史',
                style: textTheme.titleSmall?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_searchHistory.isNotEmpty)
                TextButton.icon(
                  onPressed: _clearHistory,
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                  label: Text(
                    '清除',
                    style: textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // 历史记录列表
        Expanded(
          child: _searchHistory.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 48,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: Spacing.md),
                      Text(
                        '暂无搜索历史',
                        style: textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                  itemCount: _searchHistory.length,
                  itemBuilder: (context, index) {
                    final keyword = _searchHistory[index];
                    return _buildHistoryItem(keyword, cs, textTheme);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHistoryItem(String keyword, ColorScheme cs, TextTheme textTheme) {
    return ListTile(
      leading: Icon(
        Icons.history,
        size: 20,
        color: cs.onSurfaceVariant,
      ),
      title: Text(
        keyword,
        style: textTheme.bodyMedium?.copyWith(color: cs.onSurface),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        icon: Icon(
          Icons.close,
          size: 18,
          color: cs.onSurfaceVariant,
        ),
        onPressed: () => _removeHistoryItem(keyword),
        tooltip: '删除',
      ),
      onTap: () {
        _searchController.text = keyword;
        _handleSearch(keyword);
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      dense: true,
    );
  }
}
