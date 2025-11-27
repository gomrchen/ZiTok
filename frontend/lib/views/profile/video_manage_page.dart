import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../services/user_service.dart';
import '../../app.dart';

class VideoManagePage extends StatefulWidget {
  final String id;
  final String title;
  final String description;
  final List<String> tags;
  final String? coverUrl;
  final int likes;
  final int favorites;
  final int views;

  const VideoManagePage({
    super.key,
    required this.id,
    required this.title,
    required this.description,
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
      description: extra['description'] ?? '',
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
  late String _description;
  late List<String> _tags;
  String? _coverUrl;
  File? _selectedCoverFile; // 新增：选择的封面文件
  bool _deleting = false;
  int _commentsCount = 0;
  bool _loadingComments = false;
  bool _uploadingCover = false; // 新增：上传封面状态

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();

  late UserService _userService;

  @override
  void initState() {
    super.initState();
    _userService = UserService(AppBootstrap.apiClient.dio);

    _title = widget.title;
    _description = widget.description;
    _tags = List.from(widget.tags);
    _coverUrl = widget.coverUrl;

    _titleController.text = _title;
    _descriptionController.text = _description;
    _tagsController.text = _tags.join(', ');

    _loadCommentsCount();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  // 加载评论数的方法
  Future<void> _loadCommentsCount() async {
    if (widget.id.isEmpty) return;

    setState(() {
      _loadingComments = true;
    });

    try {
      print('🔍 开始获取视频 ${widget.id} 的评论数');

      final response = await _userService.getComments(
        videoId: widget.id,
        page: 1,
        size: 999,
      );

      if (response['code'] == '10000') {
        final List<dynamic> comments = response['data'] ?? [];
        setState(() {
          _commentsCount = comments.length;
        });
        print('✅ 成功获取评论数: $_commentsCount');
      } else {
        print('❌ 获取评论数失败: ${response['message']}');
        setState(() {
          _commentsCount = 0;
        });
      }
    } catch (e) {
      print('❌ 获取评论数异常: $e');
      setState(() {
        _commentsCount = 0;
      });
    } finally {
      setState(() {
        _loadingComments = false;
      });
    }
  }

  // 修改：选择封面图片并上传
  Future<void> _pickCoverImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1080,
    );

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      await _uploadCoverImage(file);
    }
  }

  // 新增：上传封面图片
  Future<void> _uploadCoverImage(File coverFile) async {
    if (widget.id.isEmpty) {
      _showError('视频ID为空，无法上传封面');
      return;
    }

    setState(() {
      _uploadingCover = true;
      _selectedCoverFile = coverFile; // 先显示本地选择的图片
    });

    try {
      print('🔼 开始上传视频封面，videoId: ${widget.id}');

      final response = await _userService.uploadVideoCover(
        videoId: widget.id,
        coverFile: coverFile,
      );

      if (response['code'] == '10000') {
        // 假设服务器返回新的封面URL
        final String? newCoverUrl = response['data']?['cover_url'] ?? response['data']?['coverUrl'];

        if (newCoverUrl != null) {
          setState(() {
            _coverUrl = newCoverUrl;
            _selectedCoverFile = null; // 上传成功后清除本地文件引用
          });
          print('✅ 封面上传成功: $newCoverUrl');
          _showSuccess('封面上传成功');
        } else {
          throw Exception('服务器未返回封面URL');
        }
      } else {
        throw Exception('上传失败: ${response['message']}');
      }

    } catch (e) {
      print('❌ 封面上传失败: $e');
      _showError('封面上传失败: $e');
      // 上传失败时保留本地选择的图片，但标记上传失败
    } finally {
      setState(() {
        _uploadingCover = false;
      });
    }
  }

  // 修改：保存更改，包括封面更新
  Future<void> _saveChanges() async {
    setState(() {
      _tags = _tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    });

    try {
      // 如果有新封面且已上传，更新视频信息
      if (_coverUrl != null && _coverUrl != widget.coverUrl) {
        await _userService.updateVideoInfo(
          videoId: widget.id,
          tags: _tags,
          coverUrl: _coverUrl,
        );
      } else {
        // 只更新标签
        await _userService.updateVideoInfo(
          videoId: widget.id,
          tags: _tags,
        );
      }

      _showSuccess('保存成功');
    } catch (e) {
      print('❌ 保存失败: $e');
      _showError('保存失败: $e');
    }
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
                _deleteVideo();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteVideo() async {
    if (_deleting) return;

    setState(() {
      _deleting = true;
    });

    try {
      print('🗑️ 开始删除视频，videoId: ${widget.id}');

      final response = await _userService.deleteVideo(videoId: widget.id);

      if (response.statusCode == 200) {
        print('✅ 视频删除成功');
        _showSuccess('视频已删除');

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            context.pop();
          }
        });
      } else {
        throw Exception('删除失败: ${response.statusCode}');
      }

    } catch (e) {
      print('❌ 删除视频失败: $e');
      _showError('删除失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _deleting = false;
        });
      }
    }
  }

  void _navigateToDetail() {
    context.push('/video/${widget.id}');
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
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
          // 封面图片 - 修改为支持上传状态
          Center(
          child: Stack(
          children: [
            Container(
            width: 200,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: colorScheme.surfaceContainerHighest,
              image: _selectedCoverFile != null || _coverUrl != null
                  ? DecorationImage(
                image: _selectedCoverFile != null
                    ? FileImage(_selectedCoverFile!)
                    : _coverUrl!.startsWith('http')
                    ? NetworkImage(_coverUrl!)
                    : FileImage(File(_coverUrl!)) as ImageProvider,
                fit: BoxFit.cover,
              )
                  : null,
            ),
            child: _selectedCoverFile == null && _coverUrl == null
                ? Icon(
              Icons.video_library,
              size: 48,
              color: colorScheme.onSurfaceVariant,
            )
                : _uploadingCover
                ? Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
                : null,
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: FloatingActionButton.small(
              onPressed: _uploadingCover ? null : _pickCoverImage,
              child: _uploadingCover
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Icon(Icons.edit),
            ),
          ),
          if (_uploadingCover)
      Positioned(
      top: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '上传中...',
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.white,
          ),
        ),
      ),
    ),
    ],
    ),
    ),
    const SizedBox(height: 8),
    Center(
    child: Text(
    '点击编辑图标更换封面',
    style: theme.textTheme.bodySmall?.copyWith(
    color: colorScheme.onSurfaceVariant,
    ),
    ),
    ),
    const SizedBox(height: 24),

    // 标题输入 - 设置为不可编辑
    Text(
    '标题',
    style: theme.textTheme.titleMedium?.copyWith(
    fontWeight: FontWeight.w600,
    ),
    ),
    const SizedBox(height: 8),
    TextField(
    controller: _titleController,
    enabled: false,
    style: TextStyle(
    color: colorScheme.onSurface.withOpacity(0.6),
    ),
    decoration: InputDecoration(
    hintText: '请输入视频标题',
    border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    ),
    filled: true,
    fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
    ),
    maxLines: 1,
    ),
    const SizedBox(height: 16),

    // 描述输入 - 设置为不可编辑
    Text(
    '描述',
    style: theme.textTheme.titleMedium?.copyWith(
    fontWeight: FontWeight.w600,
    ),
    ),
    const SizedBox(height: 8),
    TextField(
    controller: _descriptionController,
    enabled: false,
    style: TextStyle(
    color: colorScheme.onSurface.withOpacity(0.6),
    ),
    decoration: InputDecoration(
    hintText: '请输入视频描述',
    border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    ),
    filled: true,
    fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
    ),
    maxLines: 3,
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
    hintText: '用逗号分隔多个标签',
    border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    ),
    ),
    maxLines: 1,
    ),
    const SizedBox(height: 16),

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
    icon: Icons.chat_bubble_outline,
    label: '评论',
    value: _loadingComments
    ? '...'
        : _commentsCount.toString(),
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
    onPressed: _deleting ? null : _showDeleteDialog,
    icon: _deleting
    ? const SizedBox(
    width: 16,
    height: 16,
    child: CircularProgressIndicator(
    strokeWidth: 2,
    ),
    )
        : const Icon(Icons.delete_outline),
    label: _deleting ? const Text('删除中...') : const Text('删除视频'),
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