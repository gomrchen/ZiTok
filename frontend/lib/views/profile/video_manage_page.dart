import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../services/user_service.dart';
import '../../app.dart';
import 'package:dio/src/multipart_file.dart';
import '../../utils/url_utils.dart'; // 添加导入


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
  XFile? _selectedCoverFile;
  Uint8List? _selectedCoverBytes;
  bool _deleting = false;
  int _commentsCount = 0;
  bool _loadingComments = false;
  bool _uploadingCover = false;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();

  late UserService _userService;
  final ImagePicker _picker = ImagePicker();

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

  // 选择封面图片
  Future<void> _pickCoverImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (pickedFile != null) {
        // 读取文件字节用于预览
        final bytes = await pickedFile.readAsBytes(); // 移除类型声明
        setState(() {
          _selectedCoverFile = pickedFile;
          _selectedCoverBytes = bytes;
        });

        // 立即上传
        await _uploadCoverImage(pickedFile);
      }
    } catch (e) {
      print('❌ 选择图片失败: $e');
      _showError('选择图片失败: ${e.toString()}');
    }
  }

  // 修改：上传封面图片 - 使用修正后的参数名
  Future<void> _uploadCoverImage(XFile coverFile) async {
    if (widget.id.isEmpty) {
      _showError('视频ID为空，无法上传封面');
      return;
    }

    setState(() {
      _uploadingCover = true;
    });

    try {
      print('🔼 开始上传视频封面，videoId: ${widget.id}');

      // 读取文件字节
      final fileBytes = await coverFile.readAsBytes(); // 移除类型声明

      // 获取文件名
      String fileName = coverFile.name;
      if (fileName.isEmpty) {
        fileName = 'cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
      }

      // 创建 MultipartFile
      MultipartFile coverMultipartFile = MultipartFile.fromBytes(
        fileBytes,
        filename: fileName,
      );

      // 调用上传方法 - 使用正确的参数名
      final response = await _userService.uploadVideoCover(
        videoId: widget.id,
        coverData: coverMultipartFile,
      );
      // 检查响应状态
      if (response.statusCode == 200) {
        // 解析响应数据
        final responseData = response.data;
        if (responseData is Map<String, dynamic> && responseData['code'] == '10000') {
          // 解析返回的封面URL
          final String? newCoverUrl = _parseCoverUrlFromResponse(responseData);

          if (newCoverUrl != null) {
            // 确保使用 setState 更新状态
            setState(() {
              _coverUrl = newCoverUrl;
              _selectedCoverFile = null;
              _selectedCoverBytes = null;
            });
            print('✅ 封面上传成功: $newCoverUrl');
            _showSuccess('封面上传成功');

            // 立即保存更改，确保封面URL更新到服务器
            await _saveChanges();
          } else {
            // 如果服务器没有返回封面URL，显示成功但保留本地图片预览
            _showSuccess('封面上传成功，但未获取到新封面URL');
            print('⚠️ 封面上传成功，但服务器未返回封面URL');
          }
        } else {
          throw Exception('上传失败: ${responseData['message'] ?? '未知错误'}');
        }
      } else {
        throw Exception('上传失败: ${response.statusCode}');
      }

    } catch (e) {
      print('❌ 封面上传失败: $e');
      _showError('封面上传失败: ${e.toString()}');
    } finally {
      setState(() {
        _uploadingCover = false;
      });
    }
  }

  // 修改：增强封面URL解析方法
  String? _parseCoverUrlFromResponse(Map<String, dynamic> response) {
    print('🔍 解析封面URL响应: $response');

    // 尝试从不同的可能字段中获取封面URL
    final dynamic data = response['data'];

    String? coverUrl;

    if (data is Map<String, dynamic>) {
      coverUrl = data['cover_url'] ?? data['coverUrl'] ?? data['cover'] ?? data['url'];
    } else if (data is String) {
      coverUrl = data;
    }

    // 如果找到了封面URL，确保它是完整的URL
    if (coverUrl != null && coverUrl.isNotEmpty) {
      // 如果URL是相对路径，转换为完整URL
      if (!coverUrl.startsWith('http')) {
        coverUrl = UrlUtils.resolveStorageUrl(coverUrl, defaultDir: 'covers');
        print('🔄 转换相对路径为完整URL: $coverUrl');
      }
      print('✅ 最终封面URL: $coverUrl');
      return coverUrl;
    }

    print('❌ 未能在响应中找到封面URL');
    return null;
  }

  // 修改：保存更改 - 立即更新UI
  Future<void> _saveChanges() async {
    final newTags = _tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    setState(() {
      _tags = newTags;
    });

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
      _showError('删除失败: ${e.toString()}');
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

    // 添加调试信息
    print('🎨 构建页面 - 封面URL: $_coverUrl, 选中文件: ${_selectedCoverFile != null}, 上传中: $_uploadingCover');

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
            // 封面图片区域
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 200,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: colorScheme.surfaceContainerHighest,
                      image: _getCoverImageDecoration(),
                    ),
                    child: _buildCoverPlaceholder(),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: FloatingActionButton.small(
                      onPressed: _uploadingCover ? null : _pickCoverImage,
                      child: _buildEditButtonContent(),
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

            // 标题输入
            _buildTextField(
              label: '标题',
              controller: _titleController,
              enabled: false,
              hintText: '请输入视频标题',
              maxLines: 1,
            ),
            const SizedBox(height: 16),

            // 描述输入
            _buildTextField(
              label: '描述',
              controller: _descriptionController,
              enabled: false,
              hintText: '请输入视频描述',
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // 标签输入
            _buildTextField(
              label: '标签',
              controller: _tagsController,
              enabled: true,
              hintText: '用逗号分隔多个标签',
              maxLines: 1,
            ),
            const SizedBox(height: 16),

            // 统计数据
            _buildStatsCard(theme),
            const SizedBox(height: 24),

            // 操作按钮
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  // 构建封面图片装饰 - 确保正确显示最新封面
  DecorationImage? _getCoverImageDecoration() {
    print('🖼️ 构建封面装饰 - 选中字节: ${_selectedCoverBytes != null}, 封面URL: $_coverUrl');

    // 优先显示新选择的封面（上传中或上传失败时的本地预览）
    if (_selectedCoverBytes != null) {
      print('📱 显示本地选择的封面预览');
      return DecorationImage(
        image: MemoryImage(_selectedCoverBytes!),
        fit: BoxFit.cover,
      );
    }
    // 其次显示服务器上的最新封面URL
    else if (_coverUrl != null && _coverUrl!.isNotEmpty) {
      print('🌐 显示服务器封面URL: $_coverUrl');
      return DecorationImage(
        image: NetworkImage(_coverUrl!),
        fit: BoxFit.cover,
      );
    }
    // 最后显示初始封面URL
    else if (widget.coverUrl != null && widget.coverUrl!.isNotEmpty) {
      print('📺 显示初始封面URL: ${widget.coverUrl}');
      return DecorationImage(
        image: NetworkImage(widget.coverUrl!),
        fit: BoxFit.cover,
      );
    }

    print('❓ 没有可用的封面图片');
    return null;
  }

  // 构建封面占位符
  Widget _buildCoverPlaceholder() {
    final hasCover = _selectedCoverBytes != null ||
        (_coverUrl != null && _coverUrl!.isNotEmpty) ||
        (widget.coverUrl != null && widget.coverUrl!.isNotEmpty);

    if (hasCover) {
      return _uploadingCover
          ? Container(
        color: Colors.black54,
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      )
          : const SizedBox.shrink();
    } else {
      return Icon(
        Icons.video_library,
        size: 48,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );
    }
  }

  // 构建编辑按钮内容
  Widget _buildEditButtonContent() {
    if (_uploadingCover) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    } else {
      return const Icon(Icons.edit);
    }
  }

  // 构建文本字段
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required bool enabled,
    required String hintText,
    required int maxLines,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          style: TextStyle(
            color: enabled
                ? colorScheme.onSurface
                : colorScheme.onSurface.withOpacity(0.6),
          ),
          decoration: InputDecoration(
            hintText: hintText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: !enabled,
            fillColor: !enabled
                ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
                : null,
          ),
          maxLines: maxLines,
        ),
      ],
    );
  }

  // 构建统计卡片
  Widget _buildStatsCard(ThemeData theme) {
    return Card(
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
                  value: _loadingComments ? '...' : _commentsCount.toString(),
                  color: Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 构建操作按钮
  Widget _buildActionButtons() {
    return Row(
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