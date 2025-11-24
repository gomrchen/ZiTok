import 'package:flutter/foundation.dart';
import '../models/video.dart';
import '../services/video_service.dart';
import '../services/cache.dart';
import '../utils/url_utils.dart';

class VideoRepository {
  final VideoService api;
  final CacheManager cache;
  const VideoRepository({required this.api, required this.cache});

  Future<PagedResult<Video>> fetchDiscover(VideoQuery query) async {
    final resp = await api.list(page: query.page, size: query.pageSize);
    final root = resp.data as Map<String, dynamic>? ?? {};
    List<dynamic> raw = [];
    if (root['data'] is List) {
      raw = root['data'] as List;
    } else if (root['data'] is Map && (root['data'] as Map)['items'] is List) {
      raw = (root['data'] as Map)['items'] as List;
    } else if (root['items'] is List) {
      raw = root['items'] as List;
    }
    var items = raw.map((e) => Video.fromJson(e as Map<String, dynamic>)).toList();
    items = items
        .map((v) => v.copyWith(
              videoUrl: UrlUtils.resolveStorageUrl(v.videoUrl, defaultDir: 'videos'),
              coverUrl: UrlUtils.resolveStorageUrl(v.coverUrl, defaultDir: 'covers'),
            ))
        .toList();
    final hasMore = items.length == query.pageSize;
    debugPrint('VideoRepository.fetchDiscover: page=${query.page} size=${query.pageSize} items=${items.length}');
    if (items.isNotEmpty) {
      final sample = items.take(3).map((e) => e.videoUrl).toList();
      debugPrint('VideoRepository.fetchDiscover: sampleUrls=$sample');
    }
    return PagedResult(items: items, page: query.page, pageSize: query.pageSize, hasMore: hasMore);
  }

  Future<PagedResult<Video>> fetchFeatured(VideoQuery query) async {
    final cached = cache.getJson('video_hot');
    List<Video> items;
    if (cached != null) {
      items = (cached['items'] as List<dynamic>? ?? []).map((e) => Video.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      final resp = await api.hot(pageSize: query.pageSize, pageNum: query.page);
      final root = resp.data as Map<String, dynamic>? ?? {};
      List<dynamic> raw = [];
      if (root['data'] is List) {
        raw = root['data'] as List;
      } else if (root['data'] is Map && (root['data'] as Map)['items'] is List) {
        raw = (root['data'] as Map)['items'] as List;
      } else if (root['items'] is List) {
        raw = root['items'] as List;
      }
      items = raw.map((e) => Video.fromJson(e as Map<String, dynamic>)).toList();
      await cache.setJson('video_hot', {'items': (raw)});
    }
    items = items
        .map((v) => v.copyWith(
              videoUrl: UrlUtils.resolveStorageUrl(v.videoUrl, defaultDir: 'videos'),
              coverUrl: UrlUtils.resolveStorageUrl(v.coverUrl, defaultDir: 'covers'),
            ))
        .toList();
    final start = (query.page - 1) * query.pageSize;
    final end = (start + query.pageSize).clamp(0, items.length);
    final sliced = start < items.length ? items.sublist(start, end) : <Video>[];
    debugPrint('VideoRepository.fetchFeatured: page=${query.page} size=${query.pageSize} total=${items.length} sliced=${sliced.length}');
    if (sliced.isNotEmpty) {
      final sample = sliced.take(3).map((e) => e.videoUrl).toList();
      debugPrint('VideoRepository.fetchFeatured: sampleUrls=$sample');
    }
    return PagedResult(items: sliced, page: query.page, pageSize: query.pageSize, hasMore: end < items.length);
  }

  Future<PagedResult<Video>> fetchFollow(VideoQuery query) async {
    final resp = await api.list(page: query.page, size: query.pageSize);
    final root = resp.data as Map<String, dynamic>? ?? {};
    List<dynamic> raw = [];
    if (root['data'] is List) {
      raw = root['data'] as List;
    } else if (root['data'] is Map && (root['data'] as Map)['items'] is List) {
      raw = (root['data'] as Map)['items'] as List;
    } else if (root['items'] is List) {
      raw = root['items'] as List;
    }
    var items = raw.map((e) => Video.fromJson(e as Map<String, dynamic>)).toList();
    items = items
        .map((v) => v.copyWith(
              videoUrl: UrlUtils.resolveStorageUrl(v.videoUrl, defaultDir: 'videos'),
              coverUrl: UrlUtils.resolveStorageUrl(v.coverUrl, defaultDir: 'covers'),
            ))
        .toList();
    final start = (query.page - 1) * query.pageSize;
    final end = (start + query.pageSize).clamp(0, items.length);
    final sliced = start < items.length ? items.sublist(start, end) : <Video>[];
    debugPrint('VideoRepository.fetchFollow: page=${query.page} size=${query.pageSize} total=${items.length} sliced=${sliced.length}');
    if (sliced.isNotEmpty) {
      final sample = sliced.take(3).map((e) => e.videoUrl).toList();
      debugPrint('VideoRepository.fetchFollow: sampleUrls=$sample');
    }
    return PagedResult(items: sliced, page: query.page, pageSize: query.pageSize, hasMore: end < items.length);
  }

  Future<void> like(String videoId) async {
    await api.like(videoId: videoId);
  }

  Future<void> visit(String videoId) async {
    await api.visit(videoId: videoId);
  }

  Future<PagedResult<Video>> fetchSearch(String keyword, int page, int pageSize) async {
    final resp = await api.search(keywords: keyword, pageSize: pageSize, pageNum: page);
    final root = resp.data as Map<String, dynamic>? ?? {};
    List<dynamic> raw = [];
    if (root['data'] is List) {
      raw = root['data'] as List;
    } else if (root['data'] is Map && (root['data'] as Map)['items'] is List) {
      raw = (root['data'] as Map)['items'] as List;
    } else if (root['items'] is List) {
      raw = root['items'] as List;
    }
    var items = raw.map((e) => Video.fromJson(e as Map<String, dynamic>)).toList();
    items = items
        .map((v) => v.copyWith(
              videoUrl: UrlUtils.resolveStorageUrl(v.videoUrl, defaultDir: 'videos'),
              coverUrl: UrlUtils.resolveStorageUrl(v.coverUrl, defaultDir: 'covers'),
            ))
        .toList();
    final hasMore = items.length == pageSize;
    debugPrint('VideoRepository.fetchSearch: keyword=$keyword page=$page size=$pageSize items=${items.length}');
    return PagedResult(items: items, page: page, pageSize: pageSize, hasMore: hasMore);
  }
}
