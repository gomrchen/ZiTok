class CommentItem {
  final String id;
  final String authorId;
  String author;
  final String content;
  final DateTime time;
  final String parentId;
  String avatar;
  int likes;
  CommentItem? parent;
  final List<CommentItem> replies;
  CommentItem({
    required this.id,
    required this.authorId,
    required this.author,
    required this.content,
    required this.time,
    required this.parentId,
    this.likes = 0,
    this.avatar='',
    this.parent,
    List<CommentItem>? replies,
  }): this.replies = replies ?? [];


  factory CommentItem.fromJson(Map<String, dynamic> j) => CommentItem(
    // 将JSON中的'id'字段转换为String，如果不存在则默认为空字符串
    id: (j['id'] ?? '').toString(),
    // 将'userId'字段转换为String，如果不存在则默认为空字符串
    authorId: (j['userId'] ?? '').toString(),
    // 将'author'字段转换为String，如果不存在则默认为'未知用户'
    author: (j['author'] ?? '未知用户').toString(),
    // 将'content'字段转换为String，如果不存在则默认为空字符串
    content: (j['content'] ?? '').toString(),
    // 尝试将'time'字段解析为DateTime，如果失败或不存在则使用当前时间
    time: j['time'] != null ? DateTime.tryParse(j['time'].toString()) ?? DateTime.now() : DateTime.now(),
    // 将'parentId'字段转换为String，如果不存在则默认为空字符串
    parentId: (j['parentId'] ?? '').toString(),
    // 尝试将'likes'字段解析为int，如果失败或不存在则默认为0
    likes: int.tryParse((j['likes'] ?? 0).toString()) ?? 0,

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
