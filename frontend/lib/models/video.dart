class Video {
  final String id;
  final String title;
  final String coverUrl;
  final String videoUrl;
  final int durationSeconds;
  final String author;
  final int likes;
  final List<String> tags;

  const Video({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.videoUrl,
    required this.durationSeconds,
    required this.author,
    required this.likes,
    required this.tags,
  });
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