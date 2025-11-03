import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../repositories/notes_repository.dart';
import '../../../services/notes_service.dart';
import '../../../app.dart';
import '../../../theme/theme_tokens.dart';
import '../../../models/notes_models.dart';

/// 公共组件：Md 笔记弹窗（可拖拽查看更多，带关闭按钮）
class MdNotesBottomSheet extends StatelessWidget {
  final String videoId;
  const MdNotesBottomSheet({super.key, required this.videoId});

  Future<NoteListResp> _safeFetch() async {
    try {
      final repo = NotesRepository(api: NotesService(AppBootstrap.apiClient.dio));
      return await repo.list(videoId);
    } catch (_) {
      return const NoteListResp(count: 0, items: []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.35,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (ctx, controller) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
                child: Row(
                  children: [
                    const Icon(Icons.note, size: 20),
                    const SizedBox(width: Spacing.sm),
                    Text('关联笔记', style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    IconButton(
                      tooltip: '关闭',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: FutureBuilder<NoteListResp>(
                  future: _safeFetch(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return ListView(
                        controller: controller,
                        padding: const EdgeInsets.all(Spacing.md),
                        children: const [
                          _MarkdownPlaceholder(videoId: 'unknown'),
                        ],
                      );
                    }
                    final items = snapshot.data?.items ?? const [];
                    final children = <Widget>[];
                    if (items.isEmpty) {
                      children.add(const _MarkdownPlaceholder(videoId: 'empty'));
                    } else {
                      for (final n in items) {
                        children.add(Padding(
                          padding: const EdgeInsets.only(bottom: Spacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(n.title, style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: Spacing.sm),
                              Markdown(
                                data: n.content,
                                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                                  p: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ));
                      }
                    }
                    return ListView(
                      controller: controller,
                      padding: const EdgeInsets.all(Spacing.md),
                      children: children,
                    );
                  },
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        );
      },
    );
  }
}

class _MarkdownPlaceholder extends StatelessWidget {
  final String videoId;
  const _MarkdownPlaceholder({required this.videoId});
  @override
  Widget build(BuildContext context) {
    final text = '''# 视频笔记 #$videoId\n\n- 这是一个演示 Markdown 内容。\n- 你可以上滑查看更多。\n\n## 关键要点\n1. 物体受力分析\n2. 能量守恒与动能定理\n\n> 后端接口就绪后，这里将显示真实笔记内容。''';
    return Text(text, style: Theme.of(context).textTheme.bodyMedium);
  }
}