import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../theme/theme_tokens.dart';
import '../../utils/content_validator.dart';
import '../../providers/video_provider.dart';
import '../../services/user_session.dart';
import '../../services/user_service.dart';
import '../../services/video_service.dart';
import '../../services/notes_service.dart';
import '../../repositories/notes_repository.dart';
import '../../models/video_publish.dart';
import '../../models/video.dart';
import '../../app.dart';
import 'widgets/step_indicator.dart';
import 'widgets/upload_box.dart';
import 'video_controller.dart';
import 'markdown_preview_page.dart';
import 'markdown_editor_page.dart';

enum CreateStep { modeSelect, prepare, edit, publish }

enum PublishMode { mixed, noteOnly }

class CreatePage extends StatefulWidget {
  /// 初始发布模式（可选）：noteOnly 表示笔记单独发布模式
  final PublishMode? initialMode;

  /// 预设关联的视频（可选）：用于快速发布笔记时自动关联视频
  final Video? initialLinkedVideo;

  const CreatePage({
    super.key,
    this.initialMode,
    this.initialLinkedVideo,
  });

  @override
  State<CreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends State<CreatePage> {
  CreateStep step = CreateStep.modeSelect;
  PublishMode? publishMode;

  // 素材准备
  String? videoName;
  String? videoSource; // file path 或 url（Web 兼容）
  String? mdFileName;
  String mdContent = '';
  bool markdownEditMode = true; // 上传/编辑切换

  // 笔记单独发布模式 - 关联视频
  Video? _linkedVideo;

  // 内容编辑
  final TextEditingController _titleCtl = TextEditingController();
  final TextEditingController _descCtl = TextEditingController();
  final TextEditingController _tagCtl = TextEditingController();
  final List<String> _tags = [];
  VideoPlayerController? _vc;
  bool _vcReady = false;
  late final PageController _pageController;
  double _dragDx = 0;
  bool _boundarySnackShown = false;

  @override
  void initState() {
    super.initState();
    // 根据传入的初始参数设置状态
    if (widget.initialMode != null) {
      publishMode = widget.initialMode;
      // 如果预设了笔记模式，直接进入素材准备阶段
      step = CreateStep.prepare;
    }
    if (widget.initialLinkedVideo != null) {
      _linkedVideo = widget.initialLinkedVideo;
    }
    // 根据初始状态决定 PageController 的初始页面
    final initialPage = step == CreateStep.prepare ? 1 : 0;
    _pageController = PageController(initialPage: initialPage);
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _descCtl.dispose();
    _tagCtl.dispose();
    _vc?.dispose();
    super.dispose();
  }

  void _goTo(CreateStep s) => setState(() => step = s);

  /// 检查是否可以进入发布阶段
  String? _canEnterPublishStep() {
    final isNoteOnly = publishMode == PublishMode.noteOnly;

    // 混合模式：必须有视频
    if (!isNoteOnly && (videoSource == null || videoSource!.isEmpty)) {
      return '请先选择要发布的视频';
    }
    // 笔记模式：必须有 Markdown 内容
    if (isNoteOnly && mdContent.isEmpty) {
      return '请先添加 Markdown 笔记内容';
    }
    // 笔记模式：必须关联视频
    if (isNoteOnly && _linkedVideo == null) {
      return '请先选择要关联的视频';
    }
    // 必须有标题
    if (_titleCtl.text.trim().isEmpty) {
      return isNoteOnly ? '请输入笔记标题' : '请输入视频标题';
    }
    return null; // 可以进入
  }

  /// 检查是否有已填写的数据
  bool _hasFilledData() {
    return videoSource != null ||
        mdContent.isNotEmpty ||
        _titleCtl.text.isNotEmpty ||
        _descCtl.text.isNotEmpty ||
        _tags.isNotEmpty ||
        _linkedVideo != null;
  }

  /// 显示重新选择模式的确认弹窗
  Future<bool> _showResetModeConfirmDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final cs = Theme.of(context).colorScheme;
        return AlertDialog(
          title: const Text('重新选择模式'),
          content: const Text('重新选择发布模式将清空已填写的所有数据，确定要继续吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
              ),
              child: const Text('确定清空'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<void> _animateToStep(CreateStep s) async {
    // 返回模式选择阶段：如果已有数据，需要确认
    if (s == CreateStep.modeSelect && publishMode != null && _hasFilledData()) {
      final confirmed = await _showResetModeConfirmDialog();
      if (!confirmed) return;
      // 用户确认，清空数据
      _resetForm();
    }

    // 进入发布阶段前检查条件
    if (s == CreateStep.publish) {
      final error = _canEnterPublishStep();
      if (error != null) {
        _showBoundaryHint(error);
        return;
      }
    }

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

    // 第一阶段（模式选择）右滑：返回主界面
    if (idx == 0 && isRight) {
      Navigator.of(context).maybePop();
      return;
    }

    // 最后阶段左滑：提示已在最后
    if (idx == CreateStep.values.length - 1 && isLeft) {
      _showBoundaryHint('已在最后阶段');
      return;
    }

    // 模式选择页面左滑：必须先选择模式
    if (step == CreateStep.modeSelect && isLeft && publishMode == null) {
      _showBoundaryHint('请先选择发布模式');
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

  double _containerWidth(BoxConstraints c) {
    final w = c.maxWidth;
    return w * 0.85; // 约 85% 宽度
  }

  // 根据发布模式获取有效步骤列表
  List<CreateStep> get _effectiveSteps {
    if (publishMode == null) {
      return [CreateStep.modeSelect];
    }
    return [CreateStep.modeSelect, CreateStep.prepare, CreateStep.edit, CreateStep.publish];
  }

  int _currentStepIndex() {
    final steps = _effectiveSteps;
    final idx = steps.indexOf(step);
    return idx >= 0 ? idx : 0;
  }

  List<StepMeta> _buildStepMetas() {
    if (publishMode == null) {
      return const [
        StepMeta(icon: Icons.play_lesson, label: '发布模式'),
      ];
    }
    final isNoteOnly = publishMode == PublishMode.noteOnly;
    return [
      const StepMeta(icon: Icons.play_lesson, label: '发布模式'),
      StepMeta(
        icon: Icons.inventory_2_outlined,
        label: isNoteOnly ? '素材准备' : '素材准备',
      ),
      const StepMeta(icon: Icons.edit_note, label: '内容编辑'),
      const StepMeta(icon: Icons.rocket_launch, label: '发布'),
    ];
  }

  void _onStepTap(int index) {
    final steps = _effectiveSteps;
    if (index >= 0 && index < steps.length) {
      _animateToStep(steps[index]);
    }
  }

  Widget _buildModeSelect(double width) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '选择发布模式',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Spacing.sm),
        Text(
          '请选择您想要发布的内容类型',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Spacing.xl),
        _ModeCard(
          icon: Icons.video_library,
          title: '视频笔记混合发布',
          description: '同时发布视频和配套的 Markdown 笔记，视频为主，笔记为辅',
          isSelected: publishMode == PublishMode.mixed,
          onTap: () => setState(() => publishMode = PublishMode.mixed),
        ),
        const SizedBox(height: Spacing.lg),
        _ModeCard(
          icon: Icons.article,
          title: '笔记单独发布',
          description: '仅发布 Markdown 笔记内容，无需视频素材',
          isSelected: publishMode == PublishMode.noteOnly,
          onTap: () => setState(() => publishMode = PublishMode.noteOnly),
        ),
        const SizedBox(height: Spacing.xl),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: publishMode != null ? () => _animateToStep(CreateStep.prepare) : null,
            child: const Text('下一步 · 素材准备'),
          ),
        ),
      ],
    );
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
      // 从MD中提取标签
      final tags = ContentValidator.extractTags(content);
      for (final t in tags) {
        if (!_tags.contains(t)) _tags.add(t);
      }
    }
    // 用户取消文件选择时不做任何操作
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
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: ctl,
            maxLines: 8,
            decoration: InputDecoration(hintText: hint ?? ''),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
            ElevatedButton(onPressed: () => Navigator.pop(dialogContext, ctl.text), child: const Text('确定')),
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

  /// 打开专业 Markdown 编辑器
  Future<void> _openMarkdownEditor() async {
    final result = await openMarkdownEditor(
      context,
      initialContent: mdContent,
      title: 'Markdown 笔记编辑',
    );
    if (result != null) {
      setState(() {
        mdContent = result;
        if (mdFileName == null && result.isNotEmpty) {
          mdFileName = 'note_${DateTime.now().millisecondsSinceEpoch}.md';
        }
      });
      // 从编辑后的内容中提取标签
      final tags = ContentValidator.extractTags(result);
      for (final t in tags) {
        if (!_tags.contains(t)) _tags.add(t);
      }
    }
  }

  String? _validateBeforePublish() {
    final isNoteOnly = publishMode == PublishMode.noteOnly;

    // 视频必须存在（仅混合模式）
    if (!isNoteOnly && (videoSource == null || videoSource!.isEmpty)) {
      return '请先选择要发布的视频';
    }
    // 笔记内容必须存在（仅笔记模式）
    if (isNoteOnly && mdContent.isEmpty) {
      return '请先添加 Markdown 笔记内容';
    }
    // 标题必须存在
    if (_titleCtl.text.trim().isEmpty) {
      return isNoteOnly ? '请输入笔记标题' : '请输入视频标题';
    }
    // 文件格式校验
    if (!isNoteOnly && videoName != null && !ContentValidator.isSupportedVideo(videoName!)) {
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

    final isNoteOnly = publishMode == PublishMode.noteOnly;

    // 使用 UserSession 获取用户ID（统一的登录状态判断）
    final userSession = context.read<UserSession>();
    if (!userSession.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isNoteOnly ? '请先登录后再发布笔记' : '请先登录后再发布视频')),
      );
      return;
    }
    final userId = userSession.userId!;

    // 笔记单独发布
    if (isNoteOnly) {
      if (_linkedVideo == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先选择要关联的视频')),
        );
        return;
      }

      try {
        final notesService = NotesService(AppBootstrap.apiClient.dio);
        final notesRepo = NotesRepository(api: notesService);
        final noteId = await notesRepo.create(
          videoId: int.tryParse(_linkedVideo!.id) ?? 0,
          title: _titleCtl.text.trim(),
          content: mdContent,
          seconds: 0,
        );

        if (noteId != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('笔记发布成功！')),
          );
          _resetForm();
          _animateToStep(CreateStep.modeSelect);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('笔记发布失败，请重试')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('笔记发布失败: $e')),
          );
        }
      }
      return;
    }

    // Web平台暂不支持视频上传
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Web平台暂不支持视频上传，请使用移动端或桌面端')),
      );
      return;
    }

    // 开始发布视频
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

  /// 显示退出确认弹窗
  Future<bool> _showExitConfirmDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final cs = Theme.of(context).colorScheme;
        return AlertDialog(
          title: const Text('确认退出'),
          content: const Text('您有未保存的内容，退出后将丢失所有编辑数据，确定要退出吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('继续编辑'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
              ),
              child: const Text('确认退出'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasFilledData(),
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        // 有未保存的数据，显示确认弹窗
        final navigator = Navigator.of(context);
        final confirmed = await _showExitConfirmDialog();
        if (confirmed && mounted) {
          navigator.pop();
        }
      },
      child: Scaffold(
      appBar: null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = _containerWidth(constraints);
          final minPreviewHeight = constraints.maxHeight * 0.4;
          final isWide = constraints.maxWidth >= 900;
          // 计算水平边距以实现居中效果
          final horizontalPadding = (constraints.maxWidth - width) / 2;
          final effectivePadding = horizontalPadding > 0 ? horizontalPadding : 0.0;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: _onDragStart,
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: (details) => _onDragEnd(details),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 步骤指示器
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    effectivePadding + Spacing.lg,
                    Spacing.lg,
                    effectivePadding + Spacing.lg,
                    Spacing.lg,
                  ),
                  child: StepIndicator(
                    steps: _buildStepMetas(),
                    currentIndex: _currentStepIndex(),
                    onTap: _onStepTap,
                  ),
                ),
                // 页面内容
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 4,
                    itemBuilder: (context, index) {
                      return _buildPageContent(
                        index,
                        width,
                        minPreviewHeight,
                        isWide,
                        effectivePadding,
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
      ),
    );
  }

  Widget _buildPageContent(
    int index,
    double width,
    double minPreviewHeight,
    bool isWide,
    double horizontalPadding,
  ) {
    Widget content;
    switch (index) {
      case 0:
        content = _buildModeSelect(width);
        break;
      case 1:
        content = _buildPrepare(width);
        break;
      case 2:
        content = _buildEdit(width, minPreviewHeight, isWide);
        break;
      case 3:
        // 发布阶段：检查条件是否满足
        final error = _canEnterPublishStep();
        if (error != null) {
          content = _buildPublishPlaceholder(error);
        } else {
          content = _buildPublish(width);
        }
        break;
      default:
        content = const SizedBox.shrink();
    }

    // 使用 ListView 替代 SingleChildScrollView，更稳定
    return ListView(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding + Spacing.lg,
        Spacing.lg,
        horizontalPadding + Spacing.lg,
        Spacing.lg,
      ),
      children: [content],
    );
  }

  /// 发布阶段占位符（条件不满足时显示）
  Widget _buildPublishPlaceholder(String message) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(Spacing.xl),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: Radii.md,
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 64,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(height: Spacing.md),
              Text(
                '无法进入发布阶段',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Spacing.lg),
              FilledButton.icon(
                onPressed: () => _animateToStep(CreateStep.edit),
                icon: const Icon(Icons.arrow_back),
                label: const Text('返回编辑'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrepare(double width) {
    final isNoteOnly = publishMode == PublishMode.noteOnly;
    final cs = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 视频上传（仅混合模式显示）
        if (!isNoteOnly) ...[
          UploadBox(
            title: '从本地导入视频',
            hint: videoName == null ? 'Select file' : videoName!,
            icon: Icons.video_file,
            onTap: _pickVideo,
          ),
          const SizedBox(height: Spacing.lg),
        ],
        // 笔记单独发布模式 - 关联视频选择（必需）
        if (isNoteOnly) ...[
          _CardContainer(
            label: '关联视频（必需）',
            child: InkWell(
              onTap: _showVideoSearchDialog,
              borderRadius: Radii.md,
              child: Container(
                padding: const EdgeInsets.all(Spacing.md),
                decoration: BoxDecoration(
                  border: Border.all(color: cs.outlineVariant),
                  borderRadius: Radii.md,
                ),
                child: Row(
                  children: [
                    Icon(
                      _linkedVideo != null ? Icons.check_circle : Icons.video_library,
                      color: _linkedVideo != null ? cs.primary : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _linkedVideo != null
                                ? (_linkedVideo!.title ?? '无标题视频')
                                : '点击搜索并选择要关联的视频',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: _linkedVideo != null ? cs.onSurface : cs.onSurfaceVariant,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_linkedVideo != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '视频ID: ${_linkedVideo!.id}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_linkedVideo != null)
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _linkedVideo = null),
                        tooltip: '清除选择',
                      )
                    else
                      Icon(Icons.search, color: cs.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: Spacing.lg),
        ],
        // Markdown 笔记区域
        _CardContainer(
          label: isNoteOnly ? 'Markdown 笔记（必需）' : 'Markdown 笔记（可选）',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 内容预览/状态
              Container(
                padding: const EdgeInsets.all(Spacing.md),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: Radii.sm,
                ),
                child: Row(
                  children: [
                    Icon(
                      mdContent.isNotEmpty ? Icons.check_circle : Icons.article_outlined,
                      color: mdContent.isNotEmpty ? cs.primary : cs.onSurfaceVariant,
                      size: 20,
                    ),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: Text(
                        mdContent.isNotEmpty
                            ? '${mdContent.length} 字符${mdFileName != null ? ' · $mdFileName' : ''}'
                            : '暂无内容',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: mdContent.isNotEmpty ? cs.onSurface : cs.onSurfaceVariant,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.md),
              // 操作按钮
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickMarkdown,
                      icon: const Icon(Icons.upload_file, size: 18),
                      label: const Text('导入文件'),
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _openMarkdownEditor(),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('编辑内容'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.lg),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () {
              // 笔记模式下验证关联视频
              if (isNoteOnly && _linkedVideo == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请先选择要关联的视频')),
                );
                return;
              }
              _animateToStep(CreateStep.edit);
            },
            child: const Text('下一步 · 内容编辑'),
          ),
        ),
      ],
    );
  }

  /// 显示视频搜索选择弹窗
  Future<void> _showVideoSearchDialog() async {
    final result = await showDialog<Video>(
      context: context,
      builder: (dialogContext) => _VideoSearchDialog(),
    );
    if (result != null) {
      setState(() => _linkedVideo = result);
    }
  }

  Widget _buildEdit(double width, double minPreviewHeight, bool isWide) {
    final cs = Theme.of(context).colorScheme;
    final isNoteOnly = publishMode == PublishMode.noteOnly;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 标题输入（必填）
        _CardContainer(
          label: isNoteOnly ? '笔记标题 *' : '视频标题 *',
          child: TextField(
            controller: _titleCtl,
            decoration: InputDecoration(
              hintText: isNoteOnly ? '请输入笔记标题（必填）' : '请输入视频标题（必填）',
              border: InputBorder.none,
            ),
            maxLines: 1,
          ),
        ),
        const SizedBox(height: Spacing.lg),

        // 作品描述
        _CardContainer(
          label: '作品简介',
          child: TextField(
            controller: _descCtl,
            decoration: InputDecoration(
              hintText: isNoteOnly ? '为笔记添加简介（支持emoji表情）' : '为视频添加简介（支持emoji表情）',
              border: InputBorder.none,
            ),
            minLines: 3,
            maxLines: 6,
            keyboardType: TextInputType.multiline,
          ),
        ),
        const SizedBox(height: Spacing.lg),

        // 标签
        _CardContainer(
          label: isNoteOnly ? '笔记标签' : '视频标签',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _tagCtl,
                decoration: const InputDecoration(
                  hintText: '输入后按回车或逗号添加',
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _addTagFromInput(),
              ),
              if (_tags.isNotEmpty) ...[
                const SizedBox(height: Spacing.sm),
                Wrap(
                  spacing: Spacing.sm,
                  runSpacing: Spacing.sm,
                  children: _tags
                      .map((t) => Chip(
                            label: Text(t),
                            onDeleted: () => setState(() => _tags.remove(t)),
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: Spacing.lg),

        // 素材预览提示
        _CardContainer(
          label: '已准备的素材',
          child: Padding(
            padding: const EdgeInsets.all(Spacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 视频状态（仅混合模式显示）
                if (!isNoteOnly) ...[
                  Row(
                    children: [
                      Icon(
                        videoSource != null ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 20,
                        color: videoSource != null ? cs.primary : cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: Spacing.sm),
                      Expanded(
                        child: Text(
                          '视频：${videoName ?? '未选择'}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.sm),
                ],
                Row(
                  children: [
                    Icon(
                      mdContent.isNotEmpty ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 20,
                      color: mdContent.isNotEmpty ? cs.primary : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: Text(
                        'Markdown：${mdContent.isNotEmpty ? '${mdContent.length} 字符' : (isNoteOnly ? '未添加（必需）' : '未添加（可选）')}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Spacing.xl),

        // 下一步按钮
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () {
              // 基本验证
              if (!isNoteOnly && (videoSource == null || videoSource!.isEmpty)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请先选择要发布的视频')),
                );
                return;
              }
              if (isNoteOnly && mdContent.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请先添加 Markdown 笔记内容')),
                );
                return;
              }
              if (_titleCtl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isNoteOnly ? '请输入笔记标题' : '请输入视频标题')),
                );
                return;
              }
              _animateToStep(CreateStep.publish);
            },
            icon: const Icon(Icons.arrow_forward),
            label: const Text('下一步：发布'),
          ),
        ),
      ],
    );
  }

  Widget _buildPublish(double width) {
    final isNoteOnly = publishMode == PublishMode.noteOnly;

    // 使用独立的 StatefulWidget 来监听状态变化
    // 避免 context.watch 导致整个页面重建与 PageView 布局冲突
    return _PublishPageContent(
      isNoteOnly: isNoteOnly,
      titleText: _titleCtl.text,
      descText: _descCtl.text,
      tags: _tags,
      mdContent: mdContent,
      videoName: videoName,
      videoSource: videoSource,
      onResetAndGoBack: () {
        context.read<VideoProvider>().resetPublishProgress();
        _resetForm();
        _animateToStep(CreateStep.modeSelect);
      },
      onPop: () => Navigator.of(context).maybePop(),
      onGoToEdit: () => _animateToStep(CreateStep.edit),
      onPublish: _publish,
      onRetry: () {
        context.read<VideoProvider>().resetPublishProgress();
        _publish();
      },
      onShowVideoPreview: _showVideoPreviewDialog,
      onShowMarkdownPreview: () => openMarkdownPreview(
        context,
        content: mdContent,
        title: _titleCtl.text.isNotEmpty ? '${_titleCtl.text} - 笔记预览' : '笔记预览',
      ),
    );
  }

  /// 显示视频预览弹窗
  void _showVideoPreviewDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题栏
                Padding(
                  padding: const EdgeInsets.all(Spacing.md),
                  child: Row(
                    children: [
                      const Icon(Icons.play_circle_outline),
                      const SizedBox(width: Spacing.sm),
                      Expanded(
                        child: Text(
                          '视频预览',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                ),
                // 视频播放器
                Flexible(
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
                // 控制按钮
                if (_vc != null && _vcReady)
                  Padding(
                    padding: const EdgeInsets.all(Spacing.md),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(_vc!.value.isPlaying ? Icons.pause : Icons.play_arrow),
                          onPressed: () {
                            if (_vc!.value.isPlaying) {
                              _vc!.pause();
                            } else {
                              _vc!.play();
                            }
                            // 刷新对话框
                            (dialogContext as Element).markNeedsBuild();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.replay),
                          onPressed: () {
                            _vc!.seekTo(Duration.zero);
                            _vc!.play();
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _resetForm() {
    setState(() {
      publishMode = null;
      videoName = null;
      videoSource = null;
      mdFileName = null;
      mdContent = '';
      _linkedVideo = null;
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

class _MarkdownEditor extends StatefulWidget {
  final String content;
  final ValueChanged<String> onChanged;
  const _MarkdownEditor({required this.content, required this.onChanged});

  @override
  State<_MarkdownEditor> createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<_MarkdownEditor> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.content);
  }

  @override
  void didUpdateWidget(covariant _MarkdownEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update if content changed externally (e.g., file loaded)
    if (widget.content != oldWidget.content && widget.content != _controller.text) {
      _controller.text = widget.content;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _CardContainer(
      label: 'Markdown 编辑',
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
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
      mainAxisSize: MainAxisSize.min,
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
        mainAxisSize: MainAxisSize.min,
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
        mainAxisSize: MainAxisSize.min,
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

/// 信息行组件（用于发布信息摘要）
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: cs.onSurfaceVariant),
        const SizedBox(width: Spacing.sm),
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
        ),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// 预览卡片组件（用于视频/Markdown预览按钮）
class _PreviewCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _PreviewCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isEnabled = onTap != null;

    return Material(
      color: isEnabled ? cs.surfaceContainerLow : cs.surfaceContainerHighest,
      borderRadius: Radii.md,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.md,
        child: Container(
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            borderRadius: Radii.md,
            border: Border.all(
              color: isEnabled ? cs.outline : cs.outlineVariant,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 40,
                color: isEnabled ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: isEnabled ? cs.onSurface : cs.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (isEnabled) ...[
                const SizedBox(height: Spacing.sm),
                Text(
                  '点击预览',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.primary,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 发布模式选择卡片
class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: isSelected ? cs.primaryContainer : cs.surfaceContainerLow,
      borderRadius: Radii.md,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.md,
        child: Container(
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            borderRadius: Radii.md,
            border: Border.all(
              color: isSelected ? cs.primary : cs.outlineVariant,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(Spacing.md),
                decoration: BoxDecoration(
                  color: isSelected ? cs.primary : cs.surfaceContainerHigh,
                  borderRadius: Radii.sm,
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: Spacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: isSelected ? cs.onPrimaryContainer : cs.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isSelected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: cs.primary,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 发布页面内容组件（独立监听状态，避免与 PageView 布局冲突）
class _PublishPageContent extends StatelessWidget {
  final bool isNoteOnly;
  final String titleText;
  final String descText;
  final List<String> tags;
  final String mdContent;
  final String? videoName;
  final String? videoSource;
  final VoidCallback onResetAndGoBack;
  final VoidCallback onPop;
  final VoidCallback onGoToEdit;
  final VoidCallback onPublish;
  final VoidCallback onRetry;
  final VoidCallback onShowVideoPreview;
  final VoidCallback onShowMarkdownPreview;

  const _PublishPageContent({
    required this.isNoteOnly,
    required this.titleText,
    required this.descText,
    required this.tags,
    required this.mdContent,
    required this.videoName,
    required this.videoSource,
    required this.onResetAndGoBack,
    required this.onPop,
    required this.onGoToEdit,
    required this.onPublish,
    required this.onRetry,
    required this.onShowVideoPreview,
    required this.onShowMarkdownPreview,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // 使用 Consumer 在独立组件中监听状态，不影响父组件布局
    return Consumer<VideoProvider>(
      builder: (context, provider, child) {
        final progress = provider.publishProgress;
        final isUploading = progress.isInProgress;

        if (progress.isSuccess) {
          return _buildSuccessView(context, cs);
        }

        return _buildNormalView(context, cs, progress, isUploading);
      },
    );
  }

  Widget _buildSuccessView(BuildContext context, ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CardContainer(
          label: '发布成功',
          child: Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: cs.primary,
                ),
                const SizedBox(height: Spacing.md),
                Text(
                  isNoteOnly ? '笔记发布成功！' : '视频发布成功！',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: Spacing.sm),
                Text(
                  isNoteOnly ? '您的笔记已发布' : '您的视频已提交，后台正在处理中',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Spacing.lg),
        // 使用 Wrap 替代 Row，避免布局问题
        Wrap(
          spacing: Spacing.md,
          runSpacing: Spacing.md,
          alignment: WrapAlignment.end,
          children: [
            OutlinedButton(
              onPressed: onResetAndGoBack,
              child: Text(isNoteOnly ? '发布新笔记' : '发布新视频'),
            ),
            FilledButton(
              onPressed: onPop,
              child: const Text('返回首页'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNormalView(BuildContext context, ColorScheme cs, PublishProgress progress, bool isUploading) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 发布信息摘要
        _CardContainer(
          label: '发布信息',
          child: Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(icon: Icons.title, label: '标题', value: titleText.isEmpty ? '（未填写）' : titleText),
                const SizedBox(height: Spacing.sm),
                _InfoRow(icon: Icons.description, label: '简介', value: descText.isEmpty ? '（未填写）' : descText),
                const SizedBox(height: Spacing.sm),
                _InfoRow(icon: Icons.tag, label: '标签', value: tags.isEmpty ? '（无）' : tags.join(', ')),
              ],
            ),
          ),
        ),
        const SizedBox(height: Spacing.lg),

        // 预览按钮区域
        _buildPreviewSection(context),
        const SizedBox(height: Spacing.lg),

        // 上传进度或发布按钮
        _buildActionSection(context, cs, progress, isUploading),
      ],
    );
  }

  Widget _buildPreviewSection(BuildContext context) {
    if (isNoteOnly) {
      return _PreviewCard(
        icon: Icons.article_outlined,
        title: 'Markdown 预览',
        subtitle: mdContent.isNotEmpty ? '${mdContent.length} 字符' : '未添加',
        onTap: mdContent.isNotEmpty ? onShowMarkdownPreview : null,
      );
    }
    // 使用 Column 垂直排列预览卡片，避免 Row + Expanded 的布局问题
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PreviewCard(
          icon: Icons.play_circle_outline,
          title: '视频预览',
          subtitle: videoName ?? '未选择',
          onTap: videoSource != null ? onShowVideoPreview : null,
        ),
        const SizedBox(height: Spacing.md),
        _PreviewCard(
          icon: Icons.article_outlined,
          title: 'Markdown 预览',
          subtitle: mdContent.isNotEmpty ? '${mdContent.length} 字符' : '未添加',
          onTap: mdContent.isNotEmpty ? onShowMarkdownPreview : null,
        ),
      ],
    );
  }

  Widget _buildActionSection(BuildContext context, ColorScheme cs, PublishProgress progress, bool isUploading) {
    if (isUploading) {
      return _UploadProgressWidget(progress: progress);
    }
    if (progress.isFailed) {
      return _CardContainer(
        label: '发布失败',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              progress.errorMessage ?? '未知错误',
              style: TextStyle(color: cs.error),
            ),
            const SizedBox(height: Spacing.md),
            FilledButton(
              onPressed: onRetry,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    // 使用 Wrap 替代 Row，避免布局问题
    return Wrap(
      spacing: Spacing.md,
      runSpacing: Spacing.md,
      alignment: WrapAlignment.spaceBetween,
      children: [
        OutlinedButton.icon(
          onPressed: onGoToEdit,
          icon: const Icon(Icons.arrow_back),
          label: const Text('返回编辑'),
        ),
        FilledButton.icon(
          onPressed: onPublish,
          icon: const Icon(Icons.publish),
          label: const Text('确认发布'),
        ),
      ],
    );
  }
}

/// 视频搜索选择弹窗
class _VideoSearchDialog extends StatefulWidget {
  @override
  State<_VideoSearchDialog> createState() => _VideoSearchDialogState();
}

class _VideoSearchDialogState extends State<_VideoSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Video> _myVideos = [];      // 我的视频列表
  List<Video> _searchResults = []; // 全站搜索结果
  bool _loading = false;
  bool _searching = false;         // 是否正在搜索全站
  String? _error;
  String? _userId;
  bool _isSearchMode = false;      // 是否为搜索模式

  @override
  void initState() {
    super.initState();
    _loadUserVideos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserVideos() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userSession = UserSession.instance;
      _userId = userSession.userId;

      if (_userId == null) {
        setState(() {
          _error = '请先登录';
          _loading = false;
        });
        return;
      }

      final userService = UserService(AppBootstrap.apiClient.dio);
      final videos = await userService.getVideos(
        userId: _userId!,
        page: 1,
        size: 50,
      );

      setState(() {
        _myVideos = videos;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载失败: $e';
        _loading = false;
      });
    }
  }

  /// 搜索全站视频
  Future<void> _searchAllVideos(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _isSearchMode = false;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _searching = true;
      _isSearchMode = true;
      _error = null;
    });

    try {
      final videoService = VideoService(AppBootstrap.apiClient.dio);
      final response = await videoService.search(
        keywords: query.trim(),
        pageSize: 50,
        pageNum: 1,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        List<Video> videos = [];

        if (data is Map<String, dynamic>) {
          final code = data['code'];
          if (code == '10000' || code == 10000) {
            final videoList = data['data'];
            if (videoList is List) {
              videos = videoList.map((v) => Video.fromJson(v as Map<String, dynamic>)).toList();
            }
          }
        }

        setState(() {
          _searchResults = videos;
          _searching = false;
        });
      } else {
        setState(() {
          _error = '搜索失败';
          _searching = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '搜索失败: $e';
        _searching = false;
      });
    }
  }

  /// 获取本地过滤后的视频列表（仅用于非搜索模式）
  List<Video> get _filteredMyVideos {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _myVideos;
    return _myVideos.where((v) {
      final title = (v.title ?? '').toLowerCase();
      final intro = (v.intro ?? '').toLowerCase();
      return title.contains(query) || intro.contains(query);
    }).toList();
  }

  /// 清除搜索，返回我的视频列表
  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _isSearchMode = false;
      _searchResults = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: Row(
                children: [
                  const Icon(Icons.video_library),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text('选择关联视频', style: theme.textTheme.titleMedium),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 搜索框
            Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜索全站视频（按回车搜索）',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: _clearSearch,
                          tooltip: '清除',
                        ),
                      IconButton(
                        icon: Icon(Icons.search, color: cs.primary),
                        onPressed: () => _searchAllVideos(_searchController.text),
                        tooltip: '搜索全站',
                      ),
                    ],
                  ),
                  border: OutlineInputBorder(borderRadius: Radii.md),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (value) {
                  // 如果清空了搜索框，退出搜索模式
                  if (value.isEmpty && _isSearchMode) {
                    _clearSearch();
                  } else {
                    setState(() {});
                  }
                },
                onSubmitted: _searchAllVideos,
              ),
            ),
            // 模式提示
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
              child: Row(
                children: [
                  Icon(
                    _isSearchMode ? Icons.public : Icons.person,
                    size: 16,
                    color: cs.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isSearchMode ? '全站搜索结果' : '我的视频',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_isSearchMode) ...[
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('返回我的视频'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Spacing.xs),
            // 视频列表
            Expanded(
              child: _buildVideoList(cs, theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoList(ColorScheme cs, ThemeData theme) {
    if (_loading && !_isSearchMode) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: cs.error, size: 48),
            const SizedBox(height: Spacing.md),
            Text(_error!, style: TextStyle(color: cs.error)),
            const SizedBox(height: Spacing.md),
            ElevatedButton(
              onPressed: _isSearchMode
                  ? () => _searchAllVideos(_searchController.text)
                  : _loadUserVideos,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    final videos = _isSearchMode ? _searchResults : _filteredMyVideos;

    if (videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library_outlined, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: Spacing.md),
            Text(
              _isSearchMode
                  ? '未找到匹配的视频'
                  : (_searchController.text.isNotEmpty
                      ? '未找到匹配的视频'
                      : '您还没有发布任何视频'),
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            if (!_isSearchMode && _searchController.text.isNotEmpty) ...[
              const SizedBox(height: Spacing.md),
              OutlinedButton.icon(
                onPressed: () => _searchAllVideos(_searchController.text),
                icon: const Icon(Icons.public, size: 18),
                label: const Text('搜索全站视频'),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        return _VideoSelectItem(
          video: video,
          onTap: () => Navigator.pop(context, video),
          showAuthor: _isSearchMode, // 搜索模式下显示作者
        );
      },
    );
  }
}

class _VideoSelectItem extends StatelessWidget {
  final Video video;
  final VoidCallback onTap;
  final bool showAuthor;

  const _VideoSelectItem({
    required this.video,
    required this.onTap,
    this.showAuthor = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      color: cs.surfaceContainerLow,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.md,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Row(
            children: [
              // 封面
              Container(
                width: 80,
                height: 60,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  image: video.coverUrl != null && video.coverUrl!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(video.coverUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: video.coverUrl == null || video.coverUrl!.isEmpty
                    ? Icon(Icons.video_library, color: cs.onSurfaceVariant)
                    : null,
              ),
              const SizedBox(width: Spacing.md),
              // 信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title ?? '无标题',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (showAuthor && video.authorName != null && video.authorName!.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 14, color: cs.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              video.authorName!,
                              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      'ID: ${video.id}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}