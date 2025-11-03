class Video {
  final String id;
  final String? uid;
  final String? title;
  final String? intro;
  final String? coverUrl;
  final String? videoUrl;
  final int? stars;
  final int? likes;
  final int? views;
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
    this.tags = const [],
  });

  factory Video.fromJson(Map<String, dynamic> j) => Video(
        id: (j['id'] ?? '').toString(),
        uid: j['uid']?.toString(),
        videoUrl: j['video_url'] as String?,
        coverUrl: j['cover_url'] as String?,
        intro: j['intro'] as String?,
        title: j['title'] as String?,
        stars: j['starts'] is int ? j['starts'] as int : int.tryParse('${j['starts']}'),
        likes: j['likes'] is int ? j['likes'] as int : int.tryParse('${j['likes']}'),
        views: j['views'] is int ? j['views'] as int : int.tryParse('${j['views']}'),
        tags: (j['tags'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      );
}

class VideoQuery {
  final int page;
  final int pageSize;
  final String? keyword;
  final List<String>? tags;

  const VideoQuery({this.page = 1, this.pageSize = 20, this.keyword, this.tags});
}

class PagedResult<T> {
  final List<T> items;
  final int page;
  final int pageSize;
  final bool hasMore;

  const PagedResult({required this.items, required this.page, required this.pageSize, required this.hasMore});
}