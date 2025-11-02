import 'dart:math';
import '../../models/video.dart';

class MockVideoService {
  final Random _rnd = Random(42);
  final Set<String> _followedAuthors = {'作者1', '作者2', '作者3'};
  final List<Video> _db = List.generate(200, (i) {
    final id = 'v_$i';
    final duration = 30 + (i % 240);
    return Video(
      id: id,
      title: '知识短视频 #$i',
      coverUrl: 'https://picsum.photos/seed/$i/640/360',
      // 示例视频源，使用公共CC0素材；真实项目会替换为后端返回URL
      videoUrl: i % 2 == 0
          ? 'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4'
          : 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
      durationSeconds: duration,
      author: '作者${i % 10}',
      likes: 1000 + i * 3,
      tags: ['学习', '技术', if (i % 3 == 0) '热门', if (i % 5 == 0) '推荐'],
    );
  });

  Future<PagedResult<Video>> fetch(VideoQuery query) async {
    await Future.delayed(Duration(milliseconds: 200 + _rnd.nextInt(200)));
    Iterable<Video> pool = _db;
    if (query.keyword != null && query.keyword!.isNotEmpty) {
      pool = pool.where((v) => v.title.contains(query.keyword!));
    }
    if (query.tags != null && query.tags!.isNotEmpty) {
      pool = pool.where((v) => query.tags!.any((t) => v.tags.contains(t)));
    }
    final start = (query.page - 1) * query.pageSize;
    final items = pool.skip(start).take(query.pageSize).toList();
    final hasMore = start + items.length < pool.length;
    return PagedResult(items: items, page: query.page, pageSize: query.pageSize, hasMore: hasMore);
  }

  /// 关注作者的动态作品列表
  Future<PagedResult<Video>> fetchFollow(VideoQuery query) async {
    await Future.delayed(Duration(milliseconds: 180 + _rnd.nextInt(200)));
    Iterable<Video> pool = _db.where((v) => _followedAuthors.contains(v.author));
    if (query.keyword != null && query.keyword!.isNotEmpty) {
      pool = pool.where((v) => v.title.contains(query.keyword!));
    }
    if (query.tags != null && query.tags!.isNotEmpty) {
      pool = pool.where((v) => query.tags!.any((t) => v.tags.contains(t)));
    }
    // 时间倒序更符合“关注动态”体验
    final list = pool.toList().reversed.toList();
    final start = (query.page - 1) * query.pageSize;
    final items = list.skip(start).take(query.pageSize).toList();
    final hasMore = start + items.length < list.length;
    return PagedResult(items: items, page: query.page, pageSize: query.pageSize, hasMore: hasMore);
  }
}