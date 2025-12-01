import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../app.dart';
import '../../models/notes_models.dart';
import '../../services/notes_service.dart';
import '../../repositories/notes_repository.dart';
import '../../theme/theme_tokens.dart';

class NoteManagePage extends StatefulWidget {
  final String id;
  final NoteItem? note;

  const NoteManagePage({
    super.key,
    required this.id,
    this.note,
  });

  factory NoteManagePage.fromState(GoRouterState state) {
    final extra = state.extra as Map<String, dynamic>?;
    return NoteManagePage(
      id: state.pathParameters['id'] ?? '',
      note: extra?['note'] as NoteItem?,
    );
  }

  @override
  State<NoteManagePage> createState() => _NoteManagePageState();
}

class _NoteManagePageState extends State<NoteManagePage> {
  late NoteItem? _note;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _note = widget.note;
  }

  Future<void> _deleteNote() async {
    if (_deleting) return;

    setState(() => _deleting = true);

    try {
      final notesService = NotesService(AppBootstrap.apiClient.dio);
      final notesRepo = NotesRepository(api: notesService);
      final success = await notesRepo.delete(int.tryParse(widget.id) ?? 0);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('笔记已删除')),
        );
        context.pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('删除失败，请重试')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('删除笔记'),
          content: const Text('确定要删除这个笔记吗？此操作无法撤销。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _deleteNote();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToDetail() {
    if (_note == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NoteReaderPage(note: _note!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_note == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: const Text('笔记管理'),
        ),
        body: const Center(child: Text('笔记数据不存在')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('笔记管理'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 笔记标题卡片
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(Spacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.article_outlined,
                        color: colorScheme.onPrimaryContainer,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _note!.title.isNotEmpty ? _note!.title : '无标题笔记',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '关联视频 ID: ${_note!.videoId}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Spacing.lg),

            // 统计数据
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(Spacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '数据统计',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: Spacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatItem(
                          icon: Icons.thumb_up_outlined,
                          label: '点赞',
                          value: _note!.likeCount.toString(),
                          color: Colors.blue,
                        ),
                        _StatItem(
                          icon: Icons.star,
                          label: '收藏',
                          value: _note!.favoriteCount.toString(),
                          color: Colors.amber,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Spacing.lg),

            // 内容预览
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(Spacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '内容预览',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: Spacing.sm),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 120),
                      child: Text(
                        _note!.content.isNotEmpty ? _note!.content : '暂无内容',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Spacing.xl),

            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _navigateToDetail,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('查看详情'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _deleting ? null : _showDeleteDialog,
                    icon: _deleting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline),
                    label: Text(_deleting ? '删除中...' : '删除笔记'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Markdown笔记阅读器页面（带点赞收藏功能）
class NoteReaderPage extends StatefulWidget {
  final NoteItem note;

  const NoteReaderPage({super.key, required this.note});

  @override
  State<NoteReaderPage> createState() => _NoteReaderPageState();
}

class _NoteReaderPageState extends State<NoteReaderPage> {
  late bool _isLiked;
  late bool _isFavorited;
  late int _likeCount;
  late int _favoriteCount;
  bool _likeLoading = false;
  bool _favoriteLoading = false;

  // 字体大小（默认14）
  double _fontSize = 14.0;
  static const double _minFontSize = 12.0;
  static const double _maxFontSize = 24.0;

  // 滚动控制器
  final ScrollController _scrollController = ScrollController();

  // 显示设置面板
  bool _showSettingsPanel = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.note.isLiked;
    _isFavorited = widget.note.isFavorited;
    _likeCount = widget.note.likeCount;
    _favoriteCount = widget.note.favoriteCount;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _increaseFontSize() {
    if (_fontSize < _maxFontSize) {
      setState(() => _fontSize += 2);
    }
  }

  void _decreaseFontSize() {
    if (_fontSize > _minFontSize) {
      setState(() => _fontSize -= 2);
    }
  }

  Future<void> _toggleLike() async {
    if (_likeLoading) return;

    setState(() => _likeLoading = true);

    try {
      final notesService = NotesService(AppBootstrap.apiClient.dio);
      final notesRepo = NotesRepository(api: notesService);
      final success = await notesRepo.toggleLike(int.tryParse(widget.note.id) ?? 0);

      if (success && mounted) {
        setState(() {
          _isLiked = !_isLiked;
          _likeCount += _isLiked ? 1 : -1;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _likeLoading = false);
      }
    }
  }

  Future<void> _toggleFavorite() async {
    if (_favoriteLoading) return;

    setState(() => _favoriteLoading = true);

    try {
      final notesService = NotesService(AppBootstrap.apiClient.dio);
      final notesRepo = NotesRepository(api: notesService);
      final success = await notesRepo.toggleFavorite(int.tryParse(widget.note.id) ?? 0);

      if (success && mounted) {
        setState(() {
          _isFavorited = !_isFavorited;
          _favoriteCount += _isFavorited ? 1 : -1;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _favoriteLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.note.title.isNotEmpty ? widget.note.title : '笔记详情',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // 设置按钮
          IconButton(
            onPressed: () => setState(() => _showSettingsPanel = !_showSettingsPanel),
            icon: Icon(
              Icons.text_fields,
              color: _showSettingsPanel ? cs.primary : null,
            ),
            tooltip: '阅读设置',
          ),
          // 点赞按钮
          IconButton(
            onPressed: _likeLoading ? null : _toggleLike,
            icon: _likeLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                    color: _isLiked ? Colors.blue : null,
                  ),
            tooltip: '点赞 ($_likeCount)',
          ),
          // 收藏按钮
          IconButton(
            onPressed: _favoriteLoading ? null : _toggleFavorite,
            icon: _favoriteLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _isFavorited ? Icons.star : Icons.star_outline,
                    color: _isFavorited ? Colors.amber : null,
                  ),
            tooltip: '收藏 ($_favoriteCount)',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // 主内容区域
          Container(
            color: cs.surface,
            child: Markdown(
              controller: _scrollController,
              data: widget.note.content.isNotEmpty
                  ? widget.note.content
                  : '# 暂无内容\n\n这篇笔记还没有内容。',
              padding: const EdgeInsets.all(Spacing.md),
              styleSheet: _buildMarkdownStyleSheet(theme, cs),
            ),
          ),

          // 设置面板
          if (_showSettingsPanel)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // 字体大小调整
                    Text('字体大小', style: theme.textTheme.bodyMedium),
                    const SizedBox(width: Spacing.sm),
                    IconButton(
                      onPressed: _fontSize > _minFontSize ? _decreaseFontSize : null,
                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                      tooltip: '减小字体',
                      visualDensity: VisualDensity.compact,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${_fontSize.toInt()}',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                      ),
                    ),
                    IconButton(
                      onPressed: _fontSize < _maxFontSize ? _increaseFontSize : null,
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      tooltip: '增大字体',
                      visualDensity: VisualDensity.compact,
                    ),
                    const Spacer(),
                    // 滚动控制
                    IconButton(
                      onPressed: _scrollToTop,
                      icon: const Icon(Icons.vertical_align_top, size: 20),
                      tooltip: '回到顶部',
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      onPressed: _scrollToBottom,
                      icon: const Icon(Icons.vertical_align_bottom, size: 20),
                      tooltip: '跳到底部',
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      // 浮动操作按钮：快速回到顶部
      floatingActionButton: FloatingActionButton.small(
        onPressed: _scrollToTop,
        tooltip: '回到顶部',
        child: const Icon(Icons.arrow_upward),
      ),
    );
  }

  MarkdownStyleSheet _buildMarkdownStyleSheet(ThemeData theme, ColorScheme cs) {
    return MarkdownStyleSheet(
      h1: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: cs.onSurface,
        fontSize: _fontSize + 8,
      ),
      h2: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: cs.onSurface,
        fontSize: _fontSize + 4,
      ),
      h3: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: cs.onSurface,
        fontSize: _fontSize + 2,
      ),
      p: theme.textTheme.bodyMedium?.copyWith(
        color: cs.onSurface,
        height: 1.6,
        fontSize: _fontSize,
      ),
      code: theme.textTheme.bodyMedium?.copyWith(
        backgroundColor: cs.surfaceContainerHighest,
        fontFamily: 'monospace',
        fontSize: _fontSize - 1,
      ),
      codeblockPadding: const EdgeInsets.all(12),
      codeblockDecoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      blockquote: theme.textTheme.bodyMedium?.copyWith(
        color: cs.onSurfaceVariant,
        fontStyle: FontStyle.italic,
        fontSize: _fontSize,
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: cs.primary, width: 4),
        ),
      ),
      blockquotePadding: const EdgeInsets.only(left: 16),
      listBullet: theme.textTheme.bodyMedium?.copyWith(
        color: cs.onSurface,
        fontSize: _fontSize,
      ),
    );
  }
}
