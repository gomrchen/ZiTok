class Video {
  final String id;
  final String? uid;
  final String? title;
  final String? intro;
  final String? coverUrl;
  final String? videoUrl;
  final int? stars;       // 收藏数（保留兼容）
  final int? likes;       // 点赞数（favoriteCount）
  final int? views;       // 观看数（保留兼容）
  final int? commentCount; // 评论数
  final List<String> tags;

  const Video({
    required this.id,
    this.uid,
    this.title,
    this.intro,
    this.coverUrl,
    this.videoUrl,
    this.stars,
    this.likes,
    this.views,
    this.commentCount,
    this.tags = const [],
    this.comments,
  });

  factory Video.fromJson(Map<String, dynamic> j) => Video(
        id: (j['id'] ?? '').toString(),
        uid: (j['uid'] ?? j['user_id'] ?? j['authorId'])?.toString(),
        videoUrl: (j['video_url'] as String?) ?? (j['playUrl'] as String?),
        coverUrl: (j['cover_url'] as String?) ?? (j['coverUrl'] as String?),
        intro: (j['intro'] ?? j['description']) as String?,
        title: j['title'] as String?,
        stars: j['starts'] is int
            ? j['starts'] as int
            : (j['favoriteCount'] is int
                ? j['favoriteCount'] as int
                : int.tryParse('${j['starts'] ?? j['favoriteCount']}')),
        likes: j['likes'] is int
            ? j['likes'] as int
            : (j['like_count'] is int
                ? j['like_count'] as int
                : (j['favoriteCount'] is int
                    ? j['favoriteCount'] as int
                    : int.tryParse('${j['like_count'] ?? j['likes'] ?? j['favoriteCount']}'))),
        views: j['views'] is int
            ? j['views'] as int
            : (j['visit_count'] is int ? j['visit_count'] as int : int.tryParse('${j['visit_count'] ?? j['views']}')),
        commentCount: j['commentCount'] is int
            ? j['commentCount'] as int
            : (j['comment_count'] is int
                ? j['comment_count'] as int
                : int.tryParse('${j['commentCount'] ?? j['comment_count']}')),
        tags: (j['tags'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
        comments: j['commentCount'] is int ? j['commentCount'] as int : int.tryParse('${j['commentCount']}')
      );

  Video copyWith({
    String? id,
    String? uid,
    String? title,
    String? intro,
    String? coverUrl,
    String? videoUrl,
    int? stars,
    int? likes,
    int? views,
    int? commentCount,
    List<String>? tags,
  }) {
    return Video(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      title: title ?? this.title,
      intro: intro ?? this.intro,
      coverUrl: coverUrl ?? this.coverUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      stars: stars ?? this.stars,
      likes: likes ?? this.likes,
      views: views ?? this.views,
      commentCount: commentCount ?? this.commentCount,
      tags: tags ?? this.tags,
    );
  }
}

class VideoQuery {
  final String? userId;
  final int page;
  final int pageSize;
  final String? keyword;
  final List<String>? tags;

  const VideoQuery({this.userId, this.page = 1, this.pageSize = 20, this.keyword, this.tags});
}

class PagedResult<T> {
  final List<T> items;
  final int page;
  final int pageSize;
  final bool hasMore;

  const PagedResult({required this.items, required this.page, required this.pageSize, required this.hasMore});
}
