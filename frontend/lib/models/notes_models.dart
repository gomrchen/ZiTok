class NoteItem {
  final String id;
  final String videoId;
  final String title;
  final String content;
  final int seconds; // 视频时间戳
  final int createAt;

  const NoteItem({
    required this.id,
    required this.videoId,
    required this.title,
    required this.content,
    required this.seconds,
    required this.createAt,
  });

  factory NoteItem.fromJson(Map<String, dynamic> j) => NoteItem(
        id: (j['id'] ?? '').toString(),
        videoId: (j['video_id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        content: (j['content'] ?? '').toString(),
        seconds: j['seconds'] is int ? j['seconds'] as int : int.tryParse('${j['seconds']}') ?? 0,
        createAt: j['create_at'] is int ? j['create_at'] as int : int.tryParse('${j['create_at']}') ?? 0,
      );
}

class NoteListResp {
  final int count;
  final List<NoteItem> items;
  const NoteListResp({required this.count, required this.items});
  factory NoteListResp.fromJson(Map<String, dynamic> j) => NoteListResp(
        count: j['count'] is int ? j['count'] as int : int.tryParse('${j['count']}') ?? 0,
        items: (j['items'] as List<dynamic>? ?? [])
            .map((e) => NoteItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}