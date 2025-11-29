import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../theme/theme_tokens.dart';

/// 独立的 Markdown 预览页面
///
/// 提供完整的阅读器功能：
/// - 全屏阅读体验
/// - 字体大小调节
/// - 滚动到顶部/底部
/// - 复制内容
class MarkdownPreviewPage extends StatefulWidget {
  final String content;
  final String? title;

  const MarkdownPreviewPage({
    super.key,
    required this.content,
    this.title,
  });

  @override
  State<MarkdownPreviewPage> createState() => _MarkdownPreviewPageState();
}

class _MarkdownPreviewPageState extends State<MarkdownPreviewPage> {
  final ScrollController _scrollController = ScrollController();
  double _fontSize = 16.0;
  bool _showControls = true;

  static const double _minFontSize = 12.0;
  static const double _maxFontSize = 24.0;
  static const double _fontSizeStep = 2.0;

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
      setState(() => _fontSize += _fontSizeStep);
    }
  }

  void _decreaseFontSize() {
    if (_fontSize > _minFontSize) {
      setState(() => _fontSize -= _fontSizeStep);
    }
  }

  void _copyContent() {
    Clipboard.setData(ClipboardData(text: widget.content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('内容已复制到剪贴板'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: _showControls
          ? AppBar(
              title: Text(widget.title ?? 'Markdown 预览'),
              backgroundColor: cs.surface,
              surfaceTintColor: Colors.transparent,
              actions: [
                // 字体大小控制
                IconButton(
                  icon: const Icon(Icons.text_decrease),
                  onPressed: _fontSize > _minFontSize ? _decreaseFontSize : null,
                  tooltip: '减小字体',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Center(
                    child: Text(
                      '${_fontSize.toInt()}',
                      style: textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.text_increase),
                  onPressed: _fontSize < _maxFontSize ? _increaseFontSize : null,
                  tooltip: '增大字体',
                ),
                const SizedBox(width: 8),
                // 复制按钮
                IconButton(
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: _copyContent,
                  tooltip: '复制内容',
                ),
                const SizedBox(width: 8),
              ],
            )
          : null,
      body: GestureDetector(
        onTap: _toggleControls,
        child: widget.content.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.article_outlined,
                      size: 64,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: Spacing.md),
                    Text(
                      '暂无内容',
                      style: textTheme.titleMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            : Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: Markdown(
                  controller: _scrollController,
                  data: widget.content,
                  selectable: true,
                  padding: EdgeInsets.only(
                    left: Spacing.lg,
                    right: Spacing.lg,
                    top: _showControls ? Spacing.md : Spacing.lg + 48,
                    bottom: Spacing.xl + 80,
                  ),
                  styleSheet: MarkdownStyleSheet(
                    // 标题样式
                    h1: textTheme.headlineLarge?.copyWith(
                      fontSize: _fontSize + 12,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                    h2: textTheme.headlineMedium?.copyWith(
                      fontSize: _fontSize + 8,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                    h3: textTheme.headlineSmall?.copyWith(
                      fontSize: _fontSize + 4,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                    h4: textTheme.titleLarge?.copyWith(
                      fontSize: _fontSize + 2,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                    // 正文样式
                    p: textTheme.bodyLarge?.copyWith(
                      fontSize: _fontSize,
                      height: 1.6,
                      color: cs.onSurface,
                    ),
                    // 代码块样式
                    code: TextStyle(
                      fontSize: _fontSize - 2,
                      fontFamily: 'monospace',
                      backgroundColor: cs.surfaceContainerHighest,
                      color: cs.primary,
                    ),
                    codeblockDecoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: Radii.sm,
                    ),
                    // 引用样式
                    blockquote: textTheme.bodyLarge?.copyWith(
                      fontSize: _fontSize,
                      fontStyle: FontStyle.italic,
                      color: cs.onSurfaceVariant,
                    ),
                    blockquoteDecoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: cs.primary.withValues(alpha: 0.5),
                          width: 4,
                        ),
                      ),
                    ),
                    // 列表样式
                    listBullet: textTheme.bodyLarge?.copyWith(
                      fontSize: _fontSize,
                      color: cs.primary,
                    ),
                    // 链接样式
                    a: TextStyle(
                      fontSize: _fontSize,
                      color: cs.primary,
                      decoration: TextDecoration.underline,
                    ),
                    // 分割线
                    horizontalRuleDecoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: cs.outlineVariant,
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
      // 浮动操作按钮
      floatingActionButton: _showControls
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 滚动到顶部
                FloatingActionButton.small(
                  heroTag: 'scrollTop',
                  onPressed: _scrollToTop,
                  backgroundColor: cs.secondaryContainer,
                  foregroundColor: cs.onSecondaryContainer,
                  child: const Icon(Icons.vertical_align_top),
                ),
                const SizedBox(height: Spacing.sm),
                // 滚动到底部
                FloatingActionButton.small(
                  heroTag: 'scrollBottom',
                  onPressed: _scrollToBottom,
                  backgroundColor: cs.secondaryContainer,
                  foregroundColor: cs.onSecondaryContainer,
                  child: const Icon(Icons.vertical_align_bottom),
                ),
              ],
            )
          : null,
    );
  }
}

/// 打开 Markdown 预览页面的便捷方法
Future<void> openMarkdownPreview(
  BuildContext context, {
  required String content,
  String? title,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => MarkdownPreviewPage(
        content: content,
        title: title,
      ),
    ),
  );
}
