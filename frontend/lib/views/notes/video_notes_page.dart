import 'package:flutter/material.dart';

class VideoNotesPage extends StatelessWidget {
  final String videoId;
  const VideoNotesPage({super.key, required this.videoId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('关联笔记 - 视频#$videoId')),
      body: ListView.builder(
        itemCount: 5,
        itemBuilder: (_, i) => ListTile(
          leading: const Icon(Icons.bookmark),
          title: Text('笔记条目 #$i'),
          subtitle: Text('时间戳：${i * 30}s'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}