import 'package:flutter/material.dart';
import '../../../theme/theme_tokens.dart';
import 'work_detail_sheet.dart';
import '../../../app.dart';
import '../../../services/video_service.dart';
import '../../../services/notes_service.dart';

enum WorkType { video, note }

class WorkManageSheet extends StatelessWidget {
  final WorkType type;
  const WorkManageSheet({super.key, required this.type});

  static Future<void> show(BuildContext context, {required WorkType type}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => WorkManageSheet(type: type),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(type == WorkType.video ? '我的视频' : '我的笔记', style: Theme.of(context).textTheme.titleMedium),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            ListView.separated(
              shrinkWrap: true,
              itemCount: 6,
              separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
              itemBuilder: (ctx, i) {
                return Card(
                  elevation: 0,
                  child: ListTile(
                    leading: Container(width: 48, height: 36, color: cs.surfaceContainerHighest),
                    title: Text(type == WorkType.video ? '视频作品 #$i' : '笔记作品 #$i'),
                    subtitle: const Text('发布时间：1970-01-01 08:00:00'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.info_outline),
                          onPressed: () => WorkDetailSheet.show(context),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (dctx) => AlertDialog(
                                title: const Text('确认删除'),
                                content: Text('确定删除该${type == WorkType.video ? '视频' : '笔记'}吗？'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('取消')),
                                  FilledButton(onPressed: () => Navigator.pop(dctx, true), child: const Text('删除')),
                                ],
                              ),
                            );
                            if (ok == true && ctx.mounted) {
                              if (type == WorkType.video) {
                                await VideoService(AppBootstrap.apiClient.dio).delete(videoId: '$i');
                              } else {
                                await NotesService(AppBootstrap.apiClient.dio).delete(noteId: '$i');
                              }
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('已删除')));
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}