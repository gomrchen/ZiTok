import 'package:flutter/material.dart';
import '../theme/theme_tokens.dart';

/// 简单评论区底部弹窗，占位实现。
void showCommentsSheet(BuildContext context, {required String videoId}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (context) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
                child: Row(
                  children: [
                    Text('评论 · 视频#$videoId', style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: 12,
                  itemBuilder: (_, i) => ListTile(
                    leading: CircleAvatar(child: Text('U$i')),
                    title: Text('这是一条示例评论 #$i'),
                    subtitle: Text('10-${10 + i}'),
                    trailing: const Icon(Icons.favorite_border, size: 18),
                  ),
                ),
              ),
              const Divider(height: 1),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.md),
                  child: Row(
                    children: [
                      const Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: '有爱评论，说点儿好听的',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: Spacing.md),
                      ElevatedButton(onPressed: () {}, child: const Text('发送')),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}