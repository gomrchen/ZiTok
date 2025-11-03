import '../models/video.dart';
import '../services/video_service.dart';
import '../services/cache.dart';

class VideoRepository {
  final VideoService api;
  final CacheManager cache;
  const VideoRepository({required this.api, required this.cache});

  Future<PagedResult<Video>> fetchDiscover(VideoQuery query) async {
    final resp = await api.search(content: query.keyword ?? '', pages: query.page, size: query.pageSize);
    final data = resp.data as Map<String, dynamic>? ?? {};
    final items = (data['items'] as List<dynamic>? ?? []).map((e) => Video.fromJson(e as Map<String, dynamic>)).toList();
    final count = data['count'] is int ? data['count'] as int : items.length;
    return PagedResult(items: items, page: query.page, pageSize: query.pageSize, hasMore: (items.length + query.page * query.pageSize) < count);
  }

  Future<PagedResult<Video>> fetchFeatured(VideoQuery query) async {
    // 先尝试缓存
    final cached = cache.getJson('video_popular');
    List<Video> items;
    if (cached != null) {
      items = (cached['items'] as List<dynamic>? ?? []).map((e) => Video.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      final resp = await api.popular();
      final data = resp.data as Map<String, dynamic>? ?? {};
      items = (data['items'] as List<dynamic>? ?? []).map((e) => Video.fromJson(e as Map<String, dynamic>)).toList();
      await cache.setJson('video_popular', {'items': (data['items'] ?? [])});
    }
    // 分页切片
    final start = (query.page - 1) * query.pageSize;
    final end = (start + query.pageSize).clamp(0, items.length);
    final sliced = start < items.length ? items.sublist(start, end) : <Video>[];
    return PagedResult(items: sliced, page: query.page, pageSize: query.pageSize, hasMore: end < items.length);
  }

  Future<PagedResult<Video>> fetchFollow(VideoQuery query) async {
    final resp = await api.list(uid: 0); // 后端可根据 header 中的 UID 解析当前用户，此处传0占位
    final data = resp.data as Map<String, dynamic>? ?? {};
    final items = (data['items'] as List<dynamic>? ?? []).map((e) => Video.fromJson(e as Map<String, dynamic>)).toList();
    // 分页切片
    final start = (query.page - 1) * query.pageSize;
    final end = (start + query.pageSize).clamp(0, items.length);
    final sliced = start < items.length ? items.sublist(start, end) : <Video>[];
    return PagedResult(items: sliced, page: query.page, pageSize: query.pageSize, hasMore: end < items.length);
  }
}