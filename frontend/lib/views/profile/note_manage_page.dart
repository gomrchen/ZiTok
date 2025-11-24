import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class NoteManagePage extends StatefulWidget {
  final String id;
  final String title;
  final List<String> tags;
  final int likes;
  final int favorites;
  final int reads;

  const NoteManagePage({
    super.key,
    required this.id,
    required this.title,
    required this.tags,
    required this.likes,
    required this.favorites,
    required this.reads,
  });

  factory NoteManagePage.fromState(GoRouterState state) {
    final extra = state.extra as Map<String, dynamic>;
    return NoteManagePage(
      id: state.pathParameters['id'] ?? '',
      title: extra['title'] ?? '',
      tags: List<String>.from(extra['tags'] ?? []),
      likes: extra['likes'] ?? 0,
      favorites: extra['favorites'] ?? 0,
      reads: extra['reads'] ?? 0,
    );
  }

  @override
  State<NoteManagePage> createState() => _NoteManagePageState();
}

class _NoteManagePageState extends State<NoteManagePage> {
  late String _title;
  late List<String> _tags;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();

  // 模拟笔记内容
  final String _noteContent = """# 笔记标题

这是一个示例笔记内容，用于测试markdown渲染效果。

## 主要内容

- 第一点重要内容
- 第二点补充说明
- 第三点总结归纳

## 代码示例

```dart
void main() {
  print('Hello, World!');
}
```

## 结论

这是一个完整的笔记示例，展示了markdown的基本渲染效果。
""";

  @override
  void initState() {
    super.initState();
    _title = widget.title;
    _tags = List.from(widget.tags);
    _titleController.text = _title;
    _tagsController.text = _tags.join(', ');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _saveChanges() {
    setState(() {
      _title = _titleController.text;
      _tags = _tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('保存成功')),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('删除笔记'),
          content: const Text('确定要删除这个笔记吗？此操作无法撤销。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('笔记已删除')),
                );
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) {
                    context.pop();
                  }
                });
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
    // 导航到markdown笔记详情页面
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProfileNoteDetailPage(
          title: _title,
          content: _noteContent,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('笔记管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveChanges,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题输入
            Text(
              '标题',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: '请输入笔记标题',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              ),
              maxLines: 1,
            ),
            const SizedBox(height: 16),
            
            // 标签输入
            Text(
              '标签',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _tagsController,
              decoration: InputDecoration(
                hintText: '请输入标签，用逗号分隔',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              ),
              maxLines: 1,
            ),
            const SizedBox(height: 24),
            
            // 统计数据
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '数据统计',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatItem(
                          icon: Icons.thumb_up,
                          label: '点赞',
                          value: widget.likes.toString(),
                          color: Colors.blue,
                        ),
                        _StatItem(
                          icon: Icons.favorite,
                          label: '收藏',
                          value: widget.favorites.toString(),
                          color: Colors.red,
                        ),
                        _StatItem(
                          icon: Icons.visibility,
                          label: '阅读',
                          value: widget.reads.toString(),
                          color: Colors.green,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _navigateToDetail,
                    icon: const Icon(Icons.info_outline),
                    label: const Text('查看详情'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showDeleteDialog,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('删除笔记'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
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

// Markdown笔记详情页面 (在profile包内)
class ProfileNoteDetailPage extends StatelessWidget {
  final String title;
  final String content;

  const ProfileNoteDetailPage({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(title),
      ),
      body: Container(
        color: colorScheme.surface,
        child: Markdown(
          data: content,
          styleSheet: MarkdownStyleSheet(
            h1: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            h2: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
            p: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
            ),
            code: theme.textTheme.bodyMedium?.copyWith(
              backgroundColor: colorScheme.surfaceContainerHighest,
              fontFamily: 'monospace',
            ),
            codeblockPadding: const EdgeInsets.all(12),
            codeblockDecoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}