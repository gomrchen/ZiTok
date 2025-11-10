import 'dart:math';
import '../../models/video.dart';
// Dev-only mock, no environment dependency here

class MockVideoService {
  final Random _rnd = Random(42);
  final Set<String> _followedAuthors = {'作者1', '作者2', '作者3'};
  final List<Video> _db = List.generate(200, (i) {
    final id = 'v_$i';
    return Video(
      id: id,
      title: '知识短视频 #$i',
      coverUrl: 'https://picsum.photos/seed/$i/640/360',
      // 示例视频源，使用公共CC0素材；真实项目会替换为后端返回URL
      videoUrl: i % 2 == 0
          ? 'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4'
          : 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
      likes: 1000 + i * 3,
      views: 5000 + i * 5,
      stars: (i % 5),
      tags: ['学习', '技术', if (i % 3 == 0) '热门', if (i % 5 == 0) '推荐'],
    );
  });

  Future<PagedResult<Video>> fetch(VideoQuery query) async {
    await Future.delayed(Duration(milliseconds: 200 + _rnd.nextInt(200)));
    Iterable<Video> pool = _db;
    if (query.keyword != null && query.keyword!.isNotEmpty) {
      pool = pool.where((v) => (v.title ?? '').contains(query.keyword!));
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
    // 以标签“推荐/热门”模拟关注作者动态
    Iterable<Video> pool = _db.where((v) => v.tags.contains('推荐') || v.tags.contains('热门'));
    if (query.keyword != null && query.keyword!.isNotEmpty) {
      pool = pool.where((v) => (v.title ?? '').contains(query.keyword!));
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

// 下面提供与后端路由一致的 JSON 构造方法，便于在开发环境通过 ApiClient 拦截返回 mock 数据
Map<String, dynamic> _videoToJson(Video v) => {
      'id': v.id,
      'uid': v.uid,
      'title': v.title,
      'intro': v.intro,
      'cover_url': v.coverUrl,
      'video_url': v.videoUrl,
      'starts': v.stars, // 后端字段拼写兼容
      'likes': v.likes,
      'views': v.views,
      'tags': v.tags,
    };

class MockVideoApi {
  static final MockVideoService _svc = MockVideoService();

  /// 搜索接口返回数据格式：{ items: [], count: N }
  static Map<String, dynamic> search({String? content, int page = 1, int size = 20, List<String>? tags}) {
    // 统计匹配总数并分页
    Iterable<Video> pool = _svc._db; // 访问同库内成员（library-private）
    if (content != null && content.isNotEmpty) {
      pool = pool.where((v) => (v.title ?? '').contains(content));
    }
    if (tags != null && tags.isNotEmpty) {
      pool = pool.where((v) => tags.any((t) => v.tags.contains(t)));
    }
    final total = pool.length;
    final start = (page - 1) * size;
    final items = pool.skip(start).take(size).toList();
    return {
      'items': items.map(_videoToJson).toList(),
      'count': total,
    };
  }

  /// 热门接口返回：{ items: [] }
  static Map<String, dynamic> popular({int page = 1, int size = 20}) {
    final start = (page - 1) * size;
    final items = _svc._db.skip(start).take(size).toList();
    return {
      'items': items.map(_videoToJson).toList(),
    };
  }

  /// 关注流接口返回：{ items: [] }
  static Map<String, dynamic> feed({int page = 1, int size = 20}) {
    final start = (page - 1) * size;
    final list = _svc._db.where((v) => v.tags.contains('推荐') || v.tags.contains('热门')).toList().reversed.toList();
    final items = list.skip(start).take(size).toList();
    return {
      'items': items.map(_videoToJson).toList(),
    };
  }
}
