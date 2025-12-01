import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:file_picker/file_picker.dart';
import '../../theme/theme_tokens.dart';

/// 专业 Markdown 编辑器页面
///
/// 功能特性：
/// - 功能栏：快捷语法插入、图片上传
/// - 三种模式：源码、预览、实时预览（分屏）
/// - 实时预览模式：上下分屏，滚动同步
class MarkdownEditorPage extends StatefulWidget {
  final String initialContent;
  final String? title;

  const MarkdownEditorPage({
    super.key,
    this.initialContent = '',
    this.title,
  });

  @override
  State<MarkdownEditorPage> createState() => _MarkdownEditorPageState();
}

class _MarkdownEditorPageState extends State<MarkdownEditorPage>
    with SingleTickerProviderStateMixin {
  late TextEditingController _controller;
  late ScrollController _sourceScrollController;
  late ScrollController _previewScrollController;
  late AnimationController _modeAnimController;

  EditorMode _mode = EditorMode.source;
  bool _syncing = false; // 防止滚动同步循环
  bool _hasUnsavedChanges = false; // 跟踪是否有未保存的更改

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
    _sourceScrollController = ScrollController();
    _previewScrollController = ScrollController();
    _modeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // 监听源码滚动，同步预览
    _sourceScrollController.addListener(_onSourceScroll);

    // 监听内容变化
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _sourceScrollController.dispose();
    _previewScrollController.dispose();
    _modeAnimController.dispose();
    super.dispose();
  }

  void _onSourceScroll() {
    if (_syncing || _mode != EditorMode.livePreview) return;
    if (!_sourceScrollController.hasClients || !_previewScrollController.hasClients) return;

    _syncing = true;

    final sourceMax = _sourceScrollController.position.maxScrollExtent;
    final previewMax = _previewScrollController.position.maxScrollExtent;

    if (sourceMax > 0 && previewMax > 0) {
      final ratio = _sourceScrollController.offset / sourceMax;
      _previewScrollController.jumpTo(ratio * previewMax);
    }

    _syncing = false;
  }

  void _onTextChanged() {
    // 检测是否有内容变化
    if (_controller.text != widget.initialContent && !_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
    if (_mode == EditorMode.livePreview) {
      setState(() {}); // 触发预览刷新
    }
  }

  void _setMode(EditorMode mode) {
    setState(() => _mode = mode);
  }

  /// 在光标位置插入文本
  void _insertAtCursor(String before, [String after = '']) {
    final text = _controller.text;
    final selection = _controller.selection;
    final start = selection.start;
    final end = selection.end;

    String newText;
    int newCursor;

    if (start == end) {
      // 无选中文本
      newText = text.substring(0, start) + before + after + text.substring(start);
      newCursor = start + before.length;
    } else {
      // 有选中文本，包裹选中内容
      final selected = text.substring(start, end);
      newText = text.substring(0, start) + before + selected + after + text.substring(end);
      newCursor = start + before.length + selected.length;
    }

    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
  }

  /// 插入标题
  void _insertHeading(int level) {
    final prefix = '${'#' * level} ';
    _insertAtCursor(prefix);
  }

  /// 插入粗体
  void _insertBold() => _insertAtCursor('**', '**');

  /// 插入斜体
  void _insertItalic() => _insertAtCursor('*', '*');

  /// 插入代码
  void _insertCode() => _insertAtCursor('`', '`');

  /// 插入代码块
  void _insertCodeBlock() => _insertAtCursor('```\n', '\n```');

  /// 插入链接
  void _insertLink() => _insertAtCursor('[', '](url)');

  /// 插入无序列表
  void _insertBullet() => _insertAtCursor('- ');

  /// 插入有序列表
  void _insertNumbered() => _insertAtCursor('1. ');

  /// 插入引用
  void _insertQuote() => _insertAtCursor('> ');

  /// 插入分割线
  void _insertDivider() => _insertAtCursor('\n---\n');

  /// 上传图片
  Future<void> _uploadImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        // 这里应该上传到服务器并获取URL
        // 目前使用本地路径作为占位
        final imagePath = file.path ?? file.name;
        _insertAtCursor('![${file.name}]($imagePath)');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('图片已插入（实际上传功能需要后端支持）')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('图片选择失败: $e')),
        );
      }
    }
  }

  /// 保存并返回
  void _saveAndReturn() {
    Navigator.of(context, rootNavigator: true).pop(_controller.text);
  }

  /// 处理关闭操作（带确认对话框）
  Future<void> _handleClose() async {
    if (_hasUnsavedChanges) {
      final shouldDiscard = await _showDiscardDialog();
      if (shouldDiscard == true && mounted) {
        Navigator.of(context, rootNavigator: true).pop(null);
      }
    } else {
      Navigator.of(context, rootNavigator: true).pop(null);
    }
  }

  /// 显示放弃更改确认对话框
  Future<bool?> _showDiscardDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('放弃更改？'),
        content: const Text('您有未保存的更改，确定要放弃吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('放弃'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(false);
              _saveAndReturn();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && _hasUnsavedChanges) {
          final navigator = Navigator.of(context, rootNavigator: true);
          final shouldDiscard = await _showDiscardDialog();
          if (shouldDiscard == true && mounted) {
            navigator.pop(null);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _handleClose,
            tooltip: '取消',
          ),
          title: Text(widget.title ?? 'Markdown 编辑器'),
          actions: [
            // 保存按钮
            FilledButton.icon(
              onPressed: _saveAndReturn,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('完成'),
            ),
            const SizedBox(width: 12),
          ],
        ),
      body: Column(
        children: [
          // 模式切换栏（均匀排布占满一行）
          _ModeToggleBar(
            currentMode: _mode,
            onModeChanged: _setMode,
          ),
          // 功能工具栏
          _ToolBar(
            onHeading1: () => _insertHeading(1),
            onHeading2: () => _insertHeading(2),
            onHeading3: () => _insertHeading(3),
            onBold: _insertBold,
            onItalic: _insertItalic,
            onCode: _insertCode,
            onCodeBlock: _insertCodeBlock,
            onLink: _insertLink,
            onBullet: _insertBullet,
            onNumbered: _insertNumbered,
            onQuote: _insertQuote,
            onDivider: _insertDivider,
            onImage: _uploadImage,
          ),
          const Divider(height: 1),
          // 编辑区域
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildEditorArea(cs, theme),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildEditorArea(ColorScheme cs, ThemeData theme) {
    switch (_mode) {
      case EditorMode.source:
        return _buildSourceEditor(cs, theme);
      case EditorMode.preview:
        return _buildPreview(cs, theme);
      case EditorMode.livePreview:
        return _buildLivePreview(cs, theme);
    }
  }

  /// 源码编辑器
  Widget _buildSourceEditor(ColorScheme cs, ThemeData theme) {
    return Container(
      key: const ValueKey('source'),
      color: cs.surface,
      child: TextField(
        controller: _controller,
        scrollController: _sourceScrollController,
        maxLines: null,
        expands: true,
        keyboardType: TextInputType.multiline,
        textAlignVertical: TextAlignVertical.top,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontFamily: 'monospace',
          height: 1.5,
        ),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.all(Spacing.md),
          border: InputBorder.none,
          hintText: '在此输入 Markdown 内容...',
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  /// 预览模式
  Widget _buildPreview(ColorScheme cs, ThemeData theme) {
    return Container(
      key: const ValueKey('preview'),
      color: cs.surface,
      child: Markdown(
        controller: _previewScrollController,
        data: _controller.text.isEmpty
            ? '# 预览\n\n开始输入内容后这里会显示渲染结果...'
            : _controller.text,
        padding: const EdgeInsets.all(Spacing.md),
        styleSheet: _buildMarkdownStyleSheet(theme, cs),
        selectable: true,
      ),
    );
  }

  /// 实时预览模式（分屏）
  Widget _buildLivePreview(ColorScheme cs, ThemeData theme) {
    return Column(
      key: const ValueKey('live'),
      children: [
        // 上半部分：源码
        Expanded(
          flex: 1,
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(
                bottom: BorderSide(color: cs.outlineVariant, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 源码区域标签
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.md,
                    vertical: Spacing.xs,
                  ),
                  color: cs.surfaceContainerHighest,
                  child: Row(
                    children: [
                      Icon(Icons.code, size: 16, color: cs.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(
                        '源码',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    scrollController: _sourceScrollController,
                    maxLines: null,
                    expands: true,
                    keyboardType: TextInputType.multiline,
                    textAlignVertical: TextAlignVertical.top,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      height: 1.5,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.all(Spacing.sm),
                      border: InputBorder.none,
                      hintText: '在此输入 Markdown...',
                      hintStyle: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // 下半部分：预览
        Expanded(
          flex: 1,
          child: Container(
            color: cs.surfaceContainerLow,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 预览区域标签
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.md,
                    vertical: Spacing.xs,
                  ),
                  color: cs.surfaceContainerHighest,
                  child: Row(
                    children: [
                      Icon(Icons.preview, size: 16, color: cs.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(
                        '预览',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Markdown(
                    controller: _previewScrollController,
                    data: _controller.text.isEmpty
                        ? '_输入内容后实时预览..._'
                        : _controller.text,
                    padding: const EdgeInsets.all(Spacing.sm),
                    styleSheet: _buildMarkdownStyleSheet(theme, cs, compact: true),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  MarkdownStyleSheet _buildMarkdownStyleSheet(
    ThemeData theme,
    ColorScheme cs,
    {bool compact = false}
  ) {
    final baseFontSize = compact ? 13.0 : 14.0;
    return MarkdownStyleSheet(
      h1: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: cs.onSurface,
        fontSize: compact ? 18 : 22,
      ),
      h2: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: cs.onSurface,
        fontSize: compact ? 16 : 18,
      ),
      h3: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: cs.onSurface,
        fontSize: compact ? 14 : 16,
      ),
      p: theme.textTheme.bodyMedium?.copyWith(
        color: cs.onSurface,
        height: 1.6,
        fontSize: baseFontSize,
      ),
      code: theme.textTheme.bodyMedium?.copyWith(
        backgroundColor: cs.surfaceContainerHighest,
        fontFamily: 'monospace',
        fontSize: baseFontSize - 1,
      ),
      codeblockPadding: EdgeInsets.all(compact ? 8 : 12),
      codeblockDecoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      blockquote: theme.textTheme.bodyMedium?.copyWith(
        color: cs.onSurfaceVariant,
        fontStyle: FontStyle.italic,
        fontSize: baseFontSize,
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: cs.primary, width: 4),
        ),
      ),
      blockquotePadding: const EdgeInsets.only(left: 16),
      listBullet: theme.textTheme.bodyMedium?.copyWith(
        color: cs.onSurface,
        fontSize: baseFontSize,
      ),
    );
  }
}

/// 编辑模式枚举
enum EditorMode {
  source,      // 纯源码
  preview,     // 纯预览
  livePreview, // 实时预览（分屏）
}

/// 模式切换栏（均匀排布占满一行）
class _ModeToggleBar extends StatelessWidget {
  final EditorMode currentMode;
  final ValueChanged<EditorMode> onModeChanged;

  const _ModeToggleBar({
    required this.currentMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      color: cs.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.xs),
      child: Row(
        children: [
          Expanded(
            child: _ModeTabButton(
              icon: Icons.code,
              label: '源码',
              isSelected: currentMode == EditorMode.source,
              onTap: () => onModeChanged(EditorMode.source),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ModeTabButton(
              icon: Icons.vertical_split,
              label: '实时预览',
              isSelected: currentMode == EditorMode.livePreview,
              onTap: () => onModeChanged(EditorMode.livePreview),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ModeTabButton(
              icon: Icons.preview,
              label: '预览',
              isSelected: currentMode == EditorMode.preview,
              onTap: () => onModeChanged(EditorMode.preview),
            ),
          ),
        ],
      ),
    );
  }
}

/// 模式切换按钮（带文字标签）
class _ModeTabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeTabButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Material(
      color: isSelected ? cs.primaryContainer : cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isSelected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 工具栏
class _ToolBar extends StatelessWidget {
  final VoidCallback onHeading1;
  final VoidCallback onHeading2;
  final VoidCallback onHeading3;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onCode;
  final VoidCallback onCodeBlock;
  final VoidCallback onLink;
  final VoidCallback onBullet;
  final VoidCallback onNumbered;
  final VoidCallback onQuote;
  final VoidCallback onDivider;
  final VoidCallback onImage;

  const _ToolBar({
    required this.onHeading1,
    required this.onHeading2,
    required this.onHeading3,
    required this.onBold,
    required this.onItalic,
    required this.onCode,
    required this.onCodeBlock,
    required this.onLink,
    required this.onBullet,
    required this.onNumbered,
    required this.onQuote,
    required this.onDivider,
    required this.onImage,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      color: cs.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
        child: Row(
          children: [
            // 标题
            _ToolButton(icon: Icons.looks_one, tooltip: 'H1 标题', onTap: onHeading1),
            _ToolButton(icon: Icons.looks_two, tooltip: 'H2 标题', onTap: onHeading2),
            _ToolButton(icon: Icons.looks_3, tooltip: 'H3 标题', onTap: onHeading3),
            _ToolDivider(),
            // 文本格式
            _ToolButton(icon: Icons.format_bold, tooltip: '粗体', onTap: onBold),
            _ToolButton(icon: Icons.format_italic, tooltip: '斜体', onTap: onItalic),
            _ToolButton(icon: Icons.code, tooltip: '行内代码', onTap: onCode),
            _ToolDivider(),
            // 块级元素
            _ToolButton(icon: Icons.data_object, tooltip: '代码块', onTap: onCodeBlock),
            _ToolButton(icon: Icons.format_quote, tooltip: '引用', onTap: onQuote),
            _ToolDivider(),
            // 列表
            _ToolButton(icon: Icons.format_list_bulleted, tooltip: '无序列表', onTap: onBullet),
            _ToolButton(icon: Icons.format_list_numbered, tooltip: '有序列表', onTap: onNumbered),
            _ToolDivider(),
            // 其他
            _ToolButton(icon: Icons.link, tooltip: '链接', onTap: onLink),
            _ToolButton(icon: Icons.image, tooltip: '图片', onTap: onImage),
            _ToolButton(icon: Icons.horizontal_rule, tooltip: '分割线', onTap: onDivider),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _ToolDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

/// 打开 Markdown 编辑器的便捷方法
Future<String?> openMarkdownEditor(
  BuildContext context, {
  String initialContent = '',
  String? title,
}) async {
  return Navigator.of(context, rootNavigator: true).push<String>(
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) {
        return MarkdownEditorPage(
          initialContent: initialContent,
          title: title,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween(begin: const Offset(0, 1), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 350),
    ),
  );
}
