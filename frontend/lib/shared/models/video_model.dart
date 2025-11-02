/// 简化的视频数据模型
class VideoModel {
  final String id;
  final String title;
  final String description;
  final String videoUrl;
  final String coverUrl;
  final String authorName;
  final String authorAvatar;
  final int likeCount;
  final int commentCount;
  final int shareCount;

  const VideoModel({
    required this.id,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.coverUrl,
    required this.authorName,
    required this.authorAvatar,
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
  });

  /// 创建模拟数据
  static List<VideoModel> getMockData() {
    return List.generate(10, (index) => VideoModel(
      id: 'video_$index',
      title: '视频标题 $index',
      description: '这是第 $index 个视频的描述内容',
      videoUrl: 'https://example.com/video_$index.mp4',
      coverUrl: 'https://example.com/cover_$index.jpg',
      authorName: '用户$index',
      authorAvatar: 'https://example.com/avatar_$index.jpg',
      likeCount: (index + 1) * 100,
      commentCount: (index + 1) * 20,
      shareCount: (index + 1) * 5,
    ));
  }
}