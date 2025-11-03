class CommentInfo {
  final String id;
  final String? uid;
  final String? vid;
  final String? rootId;
  final String? replyId;
  final String content;
  final int? likes;
  final String? createAt;

  const CommentInfo({
    required this.id,
    required this.content,
    this.uid,
    this.vid,
    this.rootId,
    this.replyId,
    this.likes,
    this.createAt,
  });

  factory CommentInfo.fromJson(Map<String, dynamic> j) => CommentInfo(
        id: (j['id'] ?? '').toString(),
        uid: j['uid']?.toString(),
        vid: j['vid']?.toString(),
        rootId: j['root_id']?.toString(),
        replyId: j['reply_id']?.toString(),
        content: (j['content'] ?? '').toString(),
        likes: j['likes'] is int ? j['likes'] as int : int.tryParse('${j['likes']}'),
        createAt: j['create_id']?.toString(),
      );
}

class CommentListResp {
  final int count;
  final List<CommentInfo> items;
  const CommentListResp({required this.count, required this.items});
  factory CommentListResp.fromJson(Map<String, dynamic> j) => CommentListResp(
        count: j['count'] is int ? j['count'] as int : int.tryParse('${j['count']}') ?? 0,
        items: (j['items'] as List<dynamic>? ?? [])
            .map((e) => CommentInfo.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}