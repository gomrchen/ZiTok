import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class NoteDetailPage extends StatelessWidget {
  final String id;
  final String? content;
  const NoteDetailPage({super.key, required this.id, this.content});

  @override
  Widget build(BuildContext context) {
    final md = content ?? '# 笔记\n\n这是示例内容，后续将从接口加载。\n\n- 条目A\n- 条目B';
    return Scaffold(
      appBar: AppBar(title: const Text('笔记详情')),
      body: Markdown(data: md),
    );
  }
}