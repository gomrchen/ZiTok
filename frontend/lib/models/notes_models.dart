class NoteItem {
  final String id;
  final String videoId;
  final String userId;
  final String title;
  final String content;
  final int seconds;
  final int createdAt;
  final int updatedAt;
  final int likeCount;
  final int commentCount;
  final int favoriteCount;
  final List<String> imageUrls;
  final bool isLiked;
  final bool isFavorited;

  const NoteItem({
    required this.id,
    required this.videoId,
    required this.userId,
    required this.title,
    required this.content,
    required this.seconds,
    required this.createdAt,
    required this.updatedAt,
    required this.likeCount,
    required this.commentCount,
    required this.favoriteCount,
    this.imageUrls = const [],
    this.isLiked = false,
    this.isFavorited = false,
  });

  factory NoteItem.fromJson(Map<String, dynamic> j) => NoteItem(
        id: (j['id'] ?? '').toString(),
        videoId: (j['video_id'] ?? '').toString(),
        userId: (j['user_id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        content: (j['content'] ?? '').toString(),
        seconds: _parseInt(j['seconds']),
        createdAt: _parseInt(j['created_at'] ?? j['create_at']),
        updatedAt: _parseInt(j['updated_at']),
        likeCount: _parseInt(j['like_count']),
        commentCount: _parseInt(j['comment_count']),
        favoriteCount: _parseInt(j['favorite_count']),
        imageUrls: (j['image_urls'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        isLiked: j['is_liked'] == true,
        isFavorited: j['is_favorited'] == true,
      );

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value == null) return 0;
    return int.tryParse('$value') ?? 0;
  }

  NoteItem copyWith({
    String? id,
    String? videoId,
    String? userId,
    String? title,
    String? content,
    int? seconds,
    int? createdAt,
    int? updatedAt,
    int? likeCount,
    int? commentCount,
    int? favoriteCount,
    List<String>? imageUrls,
    bool? isLiked,
    bool? isFavorited,
  }) {
    return NoteItem(
      id: id ?? this.id,
      videoId: videoId ?? this.videoId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      seconds: seconds ?? this.seconds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      imageUrls: imageUrls ?? this.imageUrls,
      isLiked: isLiked ?? this.isLiked,
      isFavorited: isFavorited ?? this.isFavorited,
    );
  }
}

class NoteListResp {
  final int total;
  final List<NoteItem> notes;

  const NoteListResp({required this.total, required this.notes});

  factory NoteListResp.fromJson(Map<String, dynamic> j) {
    final data = j['data'] as Map<String, dynamic>? ?? j;
    return NoteListResp(
      total: NoteItem._parseInt(data['total'] ?? data['count']),
      notes: (data['notes'] as List<dynamic>? ?? data['items'] as List<dynamic>? ?? [])
          .map((e) => NoteItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}