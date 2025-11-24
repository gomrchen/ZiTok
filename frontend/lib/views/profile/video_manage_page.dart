import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class VideoManagePage extends StatefulWidget {
  final String id;
  final String title;
  final List<String> tags;
  final String? coverUrl;
  final int likes;
  final int favorites;
  final int views;

  const VideoManagePage({
    super.key,
    required this.id,
    required this.title,
    required this.tags,
    this.coverUrl,
    required this.likes,
    required this.favorites,
    required this.views,
  });

  factory VideoManagePage.fromState(GoRouterState state) {
    final extra = state.extra as Map<String, dynamic>;
    return VideoManagePage(
      id: state.pathParameters['id'] ?? '',
      title: extra['title'] ?? '',
      tags: List<String>.from(extra['tags'] ?? []),
      coverUrl: extra['coverUrl'],
      likes: extra['likes'] ?? 0,
      favorites: extra['favorites'] ?? 0,
      views: extra['views'] ?? 0,
    );
  }

  @override
  State<VideoManagePage> createState() => _VideoManagePageState();
}

class _VideoManagePageState extends State<VideoManagePage> {
  late String _title;
  late List<String> _tags;
  String? _coverUrl;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _title = widget.title;
    _tags = List.from(widget.tags);
    _coverUrl = widget.coverUrl;
    _titleController.text = _title;
    _tagsController.text = _tags.join(', ');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _coverUrl = pickedFile.path;
      });
    }
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
          title: const Text('删除视频'),
          content: const Text('确定要删除这个视频吗？此操作无法撤销。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('视频已删除')),
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
    context.push('/video/${widget.id}');
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
        title: const Text('视频管理'),
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
            // 封面图片
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 200,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: colorScheme.surfaceContainerHighest,
                      image: _coverUrl != null
                          ? DecorationImage(
                              image: _coverUrl!.startsWith('http')
                                  ? NetworkImage(_coverUrl!)
                                  : FileImage(File(_coverUrl!)) as ImageProvider,
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _coverUrl == null
                        ? Icon(
                            Icons.video_library,
                            size: 48,
                            color: colorScheme.onSurfaceVariant,
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: FloatingActionButton.small(
                      onPressed: _pickCoverImage,
                      child: const Icon(Icons.edit),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
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
                hintText: '请输入视频标题',
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
                          label: '观看',
                          value: widget.views.toString(),
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
                    label: const Text('删除视频'),
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