import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../theme/theme_tokens.dart';
import '../../../app.dart';
import '../../../services/video_service.dart';
import 'work_detail_sheet.dart';

class VideoSheet extends StatefulWidget {
  final String id;
  final String title;
  final List<String> tags;
  final String? coverUrl;
  final int likes;
  final int favorites;
  final int views;
  final void Function()? onDeleted;
  const VideoSheet({super.key, required this.id, required this.title, required this.tags, this.coverUrl, this.likes = 0, this.favorites = 0, this.views = 0, this.onDeleted});

  static Future<void> show(BuildContext context, {required VideoSheet sheet}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => sheet,
    );
  }

  @override
  State<VideoSheet> createState() => _VideoSheetState();
}

class _VideoSheetState extends State<VideoSheet> {
  final _picker = ImagePicker();
  late TextEditingController _titleCtrl;
  late List<String> _tags;
  String? _coverLocal;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.title);
    _tags = List<String>.from(widget.tags);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return Material(
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('视频管理'),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.all(Spacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Row(
                      children: [
                        Container(
                          width: 96,
                          height: 64,
                          decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: Radii.sm),
                          clipBehavior: Clip.hardEdge,
                          child: _coverLocal != null
                              ? Image.file(File(_coverLocal!), fit: BoxFit.cover)
                              : (widget.coverUrl != null
                                  ? Image.network(widget.coverUrl!, fit: BoxFit.cover)
                                  : Icon(Icons.video_file, color: cs.onSurfaceVariant)),
                        ),
                        const SizedBox(width: Spacing.md),
                        Expanded(
                          child: TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: '标题')),
                        ),
                        const SizedBox(width: Spacing.sm),
                        FilledButton(onPressed: _pickCover, child: const Text('替换封面')),
                      ],
                    ),
                    const SizedBox(height: Spacing.sm),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ..._tags.map((t) => Chip(label: Text(t), onDeleted: () => setState(() => _tags.remove(t)))),
                        ActionChip(label: const Text('添加标签'), onPressed: _addTag),
                      ],
                    ),
                    const SizedBox(height: Spacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _metric(cs, Icons.thumb_up, widget.likes),
                        _metric(cs, Icons.bookmark, widget.favorites),
                        _metric(cs, Icons.visibility, widget.views),
                      ],
                    ),
                    const SizedBox(height: Spacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        OutlinedButton(onPressed: () => WorkDetailSheet.show(context), child: const Text('详情')),
                        FilledButton(onPressed: _confirmDelete, child: const Text('删除')),
                      ],
                    ),
                  ],
                ),
              ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _metric(ColorScheme cs, IconData icon, int value) {
    return Column(children: [Icon(icon, color: cs.primary), Text('$value')]);
  }

  Future<void> _addTag() async {
    final t = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(title: const Text('添加标签'), content: TextField(autofocus: true), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(ctx, '新标签'), child: const Text('添加'))]),
    );
    if (t != null && t.isNotEmpty) setState(() => _tags.add(t));
  }

  Future<void> _pickCover() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    setState(() => _coverLocal = file.path);
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(title: const Text('确认删除'), content: const Text('删除后不可恢复'), actions: [TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(dctx, true), child: const Text('删除'))]),
    );
    if (ok == true) {
      await VideoService(AppBootstrap.apiClient.dio).delete(videoId: widget.id);
      if (widget.onDeleted != null) widget.onDeleted!();
      if (mounted) Navigator.pop(context);
    }
  }
}
