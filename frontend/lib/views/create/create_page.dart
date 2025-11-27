import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../theme/theme_tokens.dart';
import '../../utils/content_validator.dart';
import '../../providers/video_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/video_publish.dart';
import 'widgets/step_indicator.dart';
import 'widgets/upload_box.dart';
import 'video_controller.dart';

enum CreateStep { prepare, edit, publish }

class CreatePage extends StatefulWidget {
  const CreatePage({super.key});

  @override
  State<CreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends State<CreatePage> {
  CreateStep step = CreateStep.prepare;

  // 素材准备
  String? videoName;
  String? videoSource; // file path 或 url（Web 兼容）
  String? mdFileName;
  String mdContent = '';
  bool markdownEditMode = true; // 上传/编辑切换

  // 内容编辑
  final TextEditingController _titleCtl = TextEditingController();
  final TextEditingController _descCtl = TextEditingController();
  final TextEditingController _tagCtl = TextEditingController();
  final List<String> _tags = [];
  VideoPlayerController? _vc;
  bool _vcReady = false;
  final PageController _pageController = PageController(initialPage: 0);
  double _dragDx = 0;
  bool _boundarySnackShown = false;

  @override
  void dispose() {
    _titleCtl.dispose();
    _descCtl.dispose();
    _tagCtl.dispose();
    _vc?.dispose();
    super.dispose();
  }

  void _goTo(CreateStep s) => setState(() => step = s);
  Future<void> _animateToStep(CreateStep s) async {
    final target = CreateStep.values.indexOf(s);
    await _pageController.animateToPage(target, duration: const Duration(milliseconds: 380), curve: Curves.easeOut);
    _goTo(s);
    _boundarySnackShown = false;
  }

  void _onDragStart(DragStartDetails d) {
    _dragDx = 0;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    _dragDx += d.delta.dx;
  }

  void _onDragEnd(DragEndDetails d) {
    const distanceThreshold = 80.0;
    const velocityThreshold = 500.0; // px/s
    final v = d.primaryVelocity ?? 0.0; // >0 右滑, <0 左滑
    final idx = CreateStep.values.indexOf(step);

    bool isLeft = _dragDx < -distanceThreshold || v < -velocityThreshold;
    bool isRight = _dragDx > distanceThreshold || v > velocityThreshold;

    if (!isLeft && !isRight) {
      // 未达到阈值，不切换
      return;
    }

    // 第一阶段右滑：返回主界面
    if (idx == 0 && isRight) {
      Navigator.of(context).maybePop();
      return;
    }
    if (idx == CreateStep.values.length - 1 && isLeft) {
      _showBoundaryHint('已在最后阶段');
      return;
    }

   

    final nextIdx = isLeft ? (idx + 1) : (idx - 1);
    final nextStep = CreateStep.values[nextIdx];
    _animateToStep(nextStep);
  }

  void _showBoundaryHint(String text) {
    if (_boundarySnackShown) return;
    _boundarySnackShown = true;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), duration: const Duration(milliseconds: 600)));
  }

  Widget _pageWrapper(Widget child) {
    return SingleChildScrollView(padding: const EdgeInsets.all(Spacing.lg), child: child);
  }

  double _containerWidth(BoxConstraints c) {
    final w = c.maxWidth;
    return w * 0.85; // 约 85% 宽度
  }

  Future<void> _pickVideo() async {
    if (kIsWeb) {
      // Web: 直接输入视频URL
      final url = await _askForText(context, title: '输入视频地址(URL)', hint: 'https://...');
      if (url != null && url.trim().isNotEmpty) {
        setState(() {
          videoSource = url.trim();
          videoName = url.split('/').last;
        });
        await _initVideoController();
      }
      return;
    }
    final res = await FilePicker.platform.pickFiles(type: FileType.video, allowMultiple: false);
    if (res != null && res.files.isNotEmpty) {
      final f = res.files.first;
      setState(() {
        videoSource = f.path;
        videoName = f.name;
      });
      await _initVideoController();
    }
  }

  Future<void> _pickMarkdown() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['md', 'markdown'],
      withData: true,
    );
    if (res != null && res.files.isNotEmpty) {
      final f = res.files.first;
      final bytes = f.bytes;
      final content = bytes != null ? utf8.decode(bytes) : '';
      setState(() {
        mdFileName = f.name;
        mdContent = content;
      });
      if (_descCtl.text.trim().isEmpty) {
        _descCtl.text = ContentValidator.summarize(content, maxLen: 100);
      }
      final tags = ContentValidator.extractTags(content);
      for (final t in tags) {
        if (!_tags.contains(t)) _tags.add(t);
      }
    } else {
      // Fallback: 允许粘贴文本
      final text = await _askForText(context, title: '粘贴 Markdown 文本', hint: '# 标题\n内容...');
      if (text != null) {
        setState(() {
          mdContent = text;
          mdFileName = 'note_${DateTime.now().millisecondsSinceEpoch}.md';
        });
        if (_descCtl.text.trim().isEmpty) {
          _descCtl.text = ContentValidator.summarize(text, maxLen: 100);
        }
        final tags = ContentValidator.extractTags(text);
        for (final t in tags) {
          if (!_tags.contains(t)) _tags.add(t);
        }
      }
    }
  }

  Future<void> _initVideoController() async {
    if (videoSource == null || videoSource!.isEmpty) return;
    try {
      _vc?.dispose();
      final c = buildVideoController(videoSource!);
      setState(() {
        _vc = c;
        _vcReady = false;
      });
      await c.initialize();
      setState(() {
        _vcReady = true;
      });
    } catch (_) {
      // 保持占位，不抛出错误
    }
  }

  Future<String?> _askForText(BuildContext context, {required String title, String? hint}) async {
    final ctl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: ctl,
            maxLines: 8,
            decoration: InputDecoration(hintText: hint ?? ''),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            ElevatedButton(onPressed: () => Navigator.pop(context, ctl.text), child: const Text('确定')),
          ],
        );
      },
    );
  }

  void _addTagFromInput() {
    final raw = _tagCtl.text.trim();
    if (raw.isEmpty) return;
    final parts = raw.split(RegExp(r'[\s,]+')).where((t) => t.isNotEmpty).map((t) => t.replaceAll('#', '')).toList();
    for (final p in parts) {
      if (!_tags.contains(p)) _tags.add(p);
    }
    _tagCtl.clear();
    setState(() {});
  }

  String? _validateBeforePublish() {
    // 视频必须存在
    if (videoSource == null || videoSource!.isEmpty) {
      return '请先选择要发布的视频';
    }
    // 标题必须存在
    if (_titleCtl.text.trim().isEmpty) {
      return '请输入视频标题';
    }
    // 文件格式校验
    if (videoName != null && !ContentValidator.isSupportedVideo(videoName!)) {
      return '不支持的视频格式（仅支持 mp4/mov/avi/mkv）';
    }
    if (mdFileName != null && !ContentValidator.isSupportedMarkdown(mdFileName!)) {
      return 'Markdown 文件扩展名不正确';
    }
    // 内容安全校验
    final illegal = ContentValidator.findIllegal('${_titleCtl.text}\n${_descCtl.text}\n$mdContent');
    if (illegal != null) return '内容含不合规词：$illegal';
    return null;
  }

  Future<void> _publish() async {
    final err = _validateBeforePublish();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }

    // 获取用户ID
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先登录后再发布视频')),
      );
      return;
    }

    // Web平台暂不支持
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Web平台暂不支持视频上传，请使用移动端或桌面端')),
      );
      return;
    }

    // 开始发布
    final videoProvider = context.read<VideoProvider>();
    final success = await videoProvider.publishVideo(
      filePath: videoSource!,
      title: _titleCtl.text.trim(),
      description: _descCtl.text.trim(),
      userId: userId,
      tags: _tags,
    );

    if (success) {
      await _animateToStep(CreateStep.publish);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 移除顶部标题栏：全屏手势区域
      appBar: null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = _containerWidth(constraints);
          final minPreviewHeight = constraints.maxHeight * 0.4; // Markdown 预览最少占屏幕 40%
          final isWide = constraints.maxWidth >= 900;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: _onDragStart,
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: (details) => _onDragEnd(details),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(Spacing.lg),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: width),
                      child: StepIndicator(
                        steps: const [
                          StepMeta(icon: Icons.inventory_2_outlined, label: '素材准备'),
                          StepMeta(icon: Icons.edit_note, label: '内容编辑'),
                          StepMeta(icon: Icons.rocket_launch, label: '发布'),
                        ],
                        currentIndex: CreateStep.values.indexOf(step),
                        onTap: (i) => _animateToStep(CreateStep.values[i]),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: width),
                      child: PageView(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _pageWrapper(_buildPrepare(width)),
                          _pageWrapper(_buildEdit(width, minPreviewHeight, isWide)),
                          _pageWrapper(_buildPublish(width)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPrepare(double width) {
    return Column(
      children: [
        UploadBox(
          title: '从本地导入视频',
          hint: videoName == null ? 'Select file' : videoName!,
          icon: Icons.video_file,
          onTap: _pickVideo,
        ),
        const SizedBox(height: Spacing.lg),
        // Markdown 上传/编辑切换
        Align(
          alignment: Alignment.centerLeft,
          child: ToggleButtons(
            isSelected: [!markdownEditMode, markdownEditMode],
            onPressed: (i) => setState(() => markdownEditMode = i == 1),
            borderRadius: Radii.md,
            children: const [
              Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('上传')),
              Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('编辑')),
            ],
          ),
        ),
        const SizedBox(height: Spacing.md),
        if (!markdownEditMode)
          UploadBox(
            title: '导入 Markdown 笔记',
            hint: mdFileName == null ? '粘贴文本或选择文件（简化）' : mdFileName!,
            icon: Icons.note_add,
            onTap: _pickMarkdown,
          )
        else
          _MarkdownEditor(
            content: mdContent,
            onChanged: (t) => setState(() => mdContent = t),
          ),
        const SizedBox(height: Spacing.lg),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () => _animateToStep(CreateStep.edit),
            child: const Text('下一步 · 内容编辑'),
          ),
        ),
      ],
    );
  }

  Widget _buildEdit(double width, double minPreviewHeight, bool isWide) {
    return Consumer<VideoProvider>(
      builder: (context, videoProvider, child) {
        final progress = videoProvider.publishProgress;
        final isUploading = progress.isInProgress;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 视频标题输入（必填）
            _CardContainer(
              label: '视频标题 *',
              child: TextField(
                controller: _titleCtl,
                enabled: !isUploading,
                decoration: const InputDecoration(
                  hintText: '请输入视频标题（必填）',
                  border: InputBorder.none,
                ),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: Spacing.lg),
            if (!isWide) ...[
              // 纵向：Markdown 预览 -> 视频预览
              _CardContainer(
                label: 'Markdown 预览',
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minPreviewHeight),
                  child: Padding(
                    padding: const EdgeInsets.all(Spacing.md),
                    child: Markdown(
                      data: mdContent.isEmpty ? '（暂无内容）' : mdContent,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Spacing.lg),
              _CardContainer(
                label: '视频预览',
                child: AspectRatio(
                  aspectRatio: _vc != null && _vc!.value.isInitialized ? _vc!.value.aspectRatio : 16 / 9,
                  child: _vc != null && _vcReady
                      ? Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            VideoPlayer(_vc!),
                            VideoProgressIndicator(_vc!, allowScrubbing: true),
                          ],
                        )
                      : _VideoPlaceholder(name: videoName),
                ),
              ),
            ] else ...[
              // 宽屏：并排布局
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _CardContainer(
                      label: 'Markdown 预览',
                      child: Builder(builder: (context) {
                        final double cardWidth = (width - Spacing.lg) / 2;
                        final double aspect = _vc != null && _vc!.value.isInitialized ? _vc!.value.aspectRatio : 16 / 9;
                        final double videoH = cardWidth / aspect;
                        final double cardHeight = videoH < minPreviewHeight ? minPreviewHeight : videoH;
                        return SizedBox(
                          height: cardHeight,
                          child: Padding(
                            padding: const EdgeInsets.all(Spacing.md),
                            child: Markdown(
                              data: mdContent.isEmpty ? '（暂无内容）' : mdContent,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: Spacing.lg),
                  Expanded(
                    child: _CardContainer(
                      label: '视频预览',
                      child: Builder(builder: (context) {
                        final double cardWidth = (width - Spacing.lg) / 2;
                        final double aspect = _vc != null && _vc!.value.isInitialized ? _vc!.value.aspectRatio : 16 / 9;
                        final double videoH = cardWidth / aspect;
                        final double cardHeight = videoH < minPreviewHeight ? minPreviewHeight : videoH;
                        return SizedBox(
                          height: cardHeight,
                          child: AspectRatio(
                            aspectRatio: aspect,
                            child: _vc != null && _vcReady
                                ? Stack(
                                    alignment: Alignment.bottomCenter,
                                    children: [
                                      VideoPlayer(_vc!),
                                      VideoProgressIndicator(_vc!, allowScrubbing: true),
                                    ],
                                  )
                                : _VideoPlaceholder(name: videoName),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: Spacing.lg),
            // 描述 & 标签
            if (!isWide) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CardContainer(
                      label: '作品描述',
                      child: TextField(
                        controller: _descCtl,
                        enabled: !isUploading,
                        decoration: const InputDecoration(
                          hintText: '为视频添加发布后描述',
                          border: InputBorder.none,
                        ),
                        minLines: 4,
                        maxLines: 8,
                      ),
                    ),
                    const SizedBox(height: Spacing.lg),
                    _CardContainer(
                      label: '视频标签',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _tagCtl,
                            enabled: !isUploading,
                            decoration: const InputDecoration(
                              hintText: '输入后按回车或逗号添加',
                              border: InputBorder.none,
                            ),
                            onSubmitted: (_) => _addTagFromInput(),
                          ),
                          const SizedBox(height: Spacing.sm),
                          Wrap(
                            spacing: Spacing.sm,
                            runSpacing: Spacing.sm,
                            children: _tags
                                .map((t) => Chip(
                                      label: Text(t),
                                      onDeleted: isUploading ? null : () => setState(() => _tags.remove(t)),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: _CardContainer(
                        label: '作品描述',
                        child: TextField(
                          controller: _descCtl,
                          enabled: !isUploading,
                          decoration: const InputDecoration(
                            hintText: '为视频添加发布后描述',
                            border: InputBorder.none,
                          ),
                          minLines: 4,
                          maxLines: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: _CardContainer(
                        label: '视频标签',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _tagCtl,
                              enabled: !isUploading,
                              decoration: const InputDecoration(
                                hintText: '输入后按回车或逗号添加',
                                border: InputBorder.none,
                              ),
                              onSubmitted: (_) => _addTagFromInput(),
                            ),
                            const SizedBox(height: Spacing.sm),
                            Wrap(
                              spacing: Spacing.sm,
                              runSpacing: Spacing.sm,
                              children: _tags
                                  .map((t) => Chip(
                                        label: Text(t),
                                        onDeleted: isUploading ? null : () => setState(() => _tags.remove(t)),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: Spacing.lg),
            // 上传进度或发布按钮
            if (isUploading) ...[
              _UploadProgressWidget(progress: progress),
            ] else if (progress.isFailed) ...[
              _CardContainer(
                label: '发布失败',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      progress.errorMessage ?? '未知错误',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                    const SizedBox(height: Spacing.md),
                    FilledButton(
                      onPressed: () {
                        videoProvider.resetPublishProgress();
                        _publish();
                      },
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(onPressed: _publish, child: const Text('发布')),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildPublish(double width) {
    return Consumer<VideoProvider>(
      builder: (context, videoProvider, child) {
        final progress = videoProvider.publishProgress;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (progress.isSuccess) ...[
              _CardContainer(
                label: '发布成功',
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: Spacing.md),
                      Text(
                        '视频发布成功！',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: Spacing.sm),
                      Text(
                        '您的视频已提交，后台正在处理中',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Spacing.lg),
              _CardContainer(
                label: '视频信息',
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [const Icon(Icons.video_file), const SizedBox(width: 8), Text(videoName ?? '无视频')]),
                      const SizedBox(height: Spacing.md),
                      Text('标题：${_titleCtl.text.isEmpty ? '（空）' : _titleCtl.text}'),
                      const SizedBox(height: Spacing.md),
                      Text('描述：${_descCtl.text.isEmpty ? '（空）' : _descCtl.text}'),
                      const SizedBox(height: Spacing.md),
                      Text('标签：${_tags.isEmpty ? '（无）' : _tags.join(', ')}'),
                    ],
                  ),
                ),
              ),
            ] else ...[
              _CardContainer(
                label: '发布预览',
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [const Icon(Icons.video_file), const SizedBox(width: 8), Text(videoName ?? '无视频')]),
                      const SizedBox(height: Spacing.md),
                      Text('标题：${_titleCtl.text.isEmpty ? '（空）' : _titleCtl.text}'),
                      const SizedBox(height: Spacing.md),
                      Text('描述：${_descCtl.text.isEmpty ? '（空）' : _descCtl.text}'),
                      const SizedBox(height: Spacing.md),
                      Text('标签：${_tags.isEmpty ? '（无）' : _tags.join(', ')}'),
                      const SizedBox(height: Spacing.md),
                      const Text('Markdown 片段：'),
                      const SizedBox(height: Spacing.sm),
                      Text(ContentValidator.summarize(mdContent, maxLen: 240)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: Spacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (progress.isSuccess) ...[
                  OutlinedButton(
                    onPressed: () {
                      videoProvider.resetPublishProgress();
                      _resetForm();
                      _animateToStep(CreateStep.prepare);
                    },
                    child: const Text('发布新视频'),
                  ),
                  const SizedBox(width: Spacing.md),
                  FilledButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('返回首页'),
                  ),
                ] else ...[
                  FilledButton(
                    onPressed: () => _animateToStep(CreateStep.edit),
                    child: const Text('返回 · 继续编辑'),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  void _resetForm() {
    setState(() {
      videoName = null;
      videoSource = null;
      mdFileName = null;
      mdContent = '';
      _titleCtl.clear();
      _descCtl.clear();
      _tagCtl.clear();
      _tags.clear();
      _vc?.dispose();
      _vc = null;
      _vcReady = false;
    });
  }
}

class _MarkdownEditor extends StatelessWidget {
  final String content;
  final ValueChanged<String> onChanged;
  const _MarkdownEditor({required this.content, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return _CardContainer(
      label: 'Markdown 编辑',
      child: TextField(
        controller: TextEditingController(text: content),
        onChanged: onChanged,
        maxLines: 16,
        decoration: const InputDecoration(
          hintText: '在此编辑 Markdown 文档...',
          border: OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _CardContainer extends StatelessWidget {
  final String label;
  final Widget child;
  const _CardContainer({required this.label, required this.child});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: Spacing.sm),
        Container(
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: Radii.md,
            border: Border.all(color: cs.outlineVariant),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  final String? name;
  const _VideoPlaceholder({this.name});
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: Radii.md,
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.play_circle_outline, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(name ?? '未选择视频'),
        ],
      ),
    );
  }
}

class _UploadProgressWidget extends StatelessWidget {
  final PublishProgress progress;
  const _UploadProgressWidget({required this.progress});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: Radii.md,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  value: progress.isUploading ? progress.progress : null,
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Text(
                  progress.message ?? '处理中...',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          if (progress.isUploading) ...[
            const SizedBox(height: Spacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.progress,
                minHeight: 8,
                backgroundColor: cs.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              '${(progress.progress * 100).toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
              textAlign: TextAlign.end,
            ),
          ],
        ],
      ),
    );
  }
}