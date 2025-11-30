import 'package:flutter/foundation.dart';
import '../models/video.dart';
import '../models/video_publish.dart';
import '../services/video_service.dart';
import '../services/cache.dart';
import '../utils/url_utils.dart';

class VideoRepository {
  final VideoService api;
  final CacheManager cache;
  final String? Function()? getUserId;
  const VideoRepository({required this.api, required this.cache, this.getUserId});

  Future<PagedResult<Video>> fetchDiscover(VideoQuery query) async {
    final resp = await api.list(userId: getUserId?.call(), page: query.page, size: query.pageSize);
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

  /// 获取关注用户发布的视频
  Future<PagedResult<Video>> fetchFollow(VideoQuery query) async {
    final userId = getUserId?.call();
    if (userId == null || userId.isEmpty) {
      debugPrint('VideoRepository.fetchFollow: no userId, returning empty');
      return PagedResult(items: [], page: query.page, pageSize: query.pageSize, hasMore: false);
    }

    final resp = await api.followFeed(userId: userId, page: query.page, size: query.pageSize);
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
    debugPrint('VideoRepository.fetchFollow: page=${query.page} size=${query.pageSize} items=${items.length} hasMore=$hasMore');
    if (items.isNotEmpty) {
      final sample = items.take(3).map((e) => '${e.title}(${e.uid})').toList();
      debugPrint('VideoRepository.fetchFollow: sample=$sample');
    }
    return PagedResult(items: items, page: query.page, pageSize: query.pageSize, hasMore: hasMore);
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

  /// 发布视频
  ///
  /// [request] 视频发布请求
  /// [onProgress] 上传进度回调 (0.0 ~ 1.0)
  Future<VideoPublishResponse> publish(
    VideoPublishRequest request, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final resp = await api.publish(
        filePath: request.filePath,
        title: request.title,
        description: request.description,
        userId: request.userId,
        onProgress: onProgress != null
            ? (sent, total) {
                final progress = total > 0 ? sent / total : 0.0;
                onProgress(progress);
              }
            : null,
      );

      final data = resp.data as Map<String, dynamic>? ?? {};
      final response = VideoPublishResponse.fromJson(data);

      if (response.isSuccess) {
        // 发布成功后清除缓存，以便刷新列表时获取最新数据
        await cache.remove('video_hot');
        debugPrint('VideoRepository.publish: success, cache cleared');
      }

      return response;
    } catch (e) {
      debugPrint('VideoRepository.publish: error=$e');
      rethrow;
    }
  }

  // ==================== 收藏相关方法 ====================

  /// 检查响应码是否表示成功
  bool _isSuccessCode(dynamic code) {
    if (code == null) return false;
    // 处理字符串和整数两种情况
    final codeStr = code.toString();
    return codeStr == '10000' || codeStr == '200' || codeStr == '0';
  }

  /// 收藏视频
  Future<bool> favorite(String videoId) async {
    try {
      final id = int.tryParse(videoId);
      if (id == null) {
        debugPrint('VideoRepository.favorite: invalid videoId=$videoId');
        return false;
      }
      final resp = await api.favorite(videoId: id);
      final data = resp.data as Map<String, dynamic>? ?? {};
      final code = data['code'];
      final success = _isSuccessCode(code);
      debugPrint('VideoRepository.favorite: videoId=$videoId code=$code success=$success');
      return success;
    } catch (e) {
      debugPrint('VideoRepository.favorite: error=$e');
      return false;
    }
  }

  /// 取消收藏
  Future<bool> unfavorite(String videoId) async {
    try {
      final id = int.tryParse(videoId);
      if (id == null) {
        debugPrint('VideoRepository.unfavorite: invalid videoId=$videoId');
        return false;
      }
      final resp = await api.unfavorite(videoId: id);
      final data = resp.data as Map<String, dynamic>? ?? {};
      final code = data['code'];
      final success = _isSuccessCode(code);
      debugPrint('VideoRepository.unfavorite: videoId=$videoId code=$code success=$success');
      return success;
    } catch (e) {
      debugPrint('VideoRepository.unfavorite: error=$e');
      return false;
    }
  }

  /// 获取收藏列表
  /// 注意：收藏列表API可能只返回视频ID或不完整的视频对象，需要额外获取视频详情
  Future<PagedResult<Video>> fetchFavorites(int page, int pageSize) async {
    try {
      final resp = await api.favorites(page: page, size: pageSize);
      final root = resp.data as Map<String, dynamic>? ?? {};
      List<dynamic> raw = [];

      // 适配多种响应格式，包括 VideoList 字段
      if (root['data'] is List) {
        raw = root['data'] as List;
      } else if (root['data'] is Map) {
        final dataMap = root['data'] as Map;
        if (dataMap['VideoList'] is List) {
          raw = dataMap['VideoList'] as List;
        } else if (dataMap['items'] is List) {
          raw = dataMap['items'] as List;
        }
      } else if (root['items'] is List) {
        raw = root['items'] as List;
      } else if (root['VideoList'] is List) {
        raw = root['VideoList'] as List;
      }

      debugPrint('VideoRepository.fetchFavorites: raw data=$raw');

      List<Video> items = [];

      for (final e in raw) {
        if (e is Map<String, dynamic>) {
          // 解析视频对象
          var video = Video.fromJson(e);

          // 检查关键字段是否完整（title和coverUrl都为空视为不完整）
          final needFetchDetail = _isVideoIncomplete(video);

          if (needFetchDetail) {
            // 关键字段缺失，需要获取详情
            debugPrint('VideoRepository.fetchFavorites: video ${video.id} incomplete, fetching detail');
            final detailVideo = await _fetchVideoDetail(video.id);
            if (detailVideo != null) {
              video = detailVideo.copyWith(isFavorited: true);
            } else {
              video = video.copyWith(isFavorited: true);
            }
          } else {
            video = video.copyWith(
              videoUrl: UrlUtils.resolveStorageUrl(video.videoUrl, defaultDir: 'videos'),
              coverUrl: UrlUtils.resolveStorageUrl(video.coverUrl, defaultDir: 'covers'),
              isFavorited: true,
            );
          }
          items.add(video);
        } else {
          // 如果只返回视频ID，需要获取视频详情
          final videoId = e.toString();
          final detailVideo = await _fetchVideoDetail(videoId);
          if (detailVideo != null) {
            items.add(detailVideo.copyWith(isFavorited: true));
          } else {
            items.add(Video(id: videoId, isFavorited: true));
          }
        }
      }

      final hasMore = raw.length == pageSize;
      debugPrint('VideoRepository.fetchFavorites: page=$page size=$pageSize items=${items.length}');
      return PagedResult(items: items, page: page, pageSize: pageSize, hasMore: hasMore);
    } catch (e) {
      debugPrint('VideoRepository.fetchFavorites: error=$e');
      return PagedResult(items: [], page: page, pageSize: pageSize, hasMore: false);
    }
  }

  /// 检查视频对象是否缺少关键信息
  bool _isVideoIncomplete(Video video) {
    final titleEmpty = video.title == null || video.title!.isEmpty;
    final coverEmpty = video.coverUrl == null || video.coverUrl!.isEmpty;
    final videoUrlEmpty = video.videoUrl == null || video.videoUrl!.isEmpty;
    // 如果标题和封面/视频URL都为空，视为不完整
    return titleEmpty && (coverEmpty || videoUrlEmpty);
  }

  /// 获取单个视频详情
  Future<Video?> _fetchVideoDetail(String videoId) async {
    try {
      final detailResp = await api.detail(videoId: videoId);
      final detailRoot = detailResp.data as Map<String, dynamic>? ?? {};
      Map<String, dynamic>? videoData;

      if (detailRoot['data'] is Map<String, dynamic>) {
        videoData = detailRoot['data'] as Map<String, dynamic>;
      } else if (detailRoot['video'] is Map<String, dynamic>) {
        videoData = detailRoot['video'] as Map<String, dynamic>;
      }

      if (videoData != null) {
        var video = Video.fromJson(videoData);
        video = video.copyWith(
          videoUrl: UrlUtils.resolveStorageUrl(video.videoUrl, defaultDir: 'videos'),
          coverUrl: UrlUtils.resolveStorageUrl(video.coverUrl, defaultDir: 'covers'),
        );
        return video;
      }
      return null;
    } catch (e) {
      debugPrint('VideoRepository._fetchVideoDetail: failed for $videoId: $e');
      return null;
    }
  }

  // ==================== 推荐相关方法 ====================

  /// 获取推荐视频
  Future<PagedResult<Video>> fetchRecommend({
    int limit = 10,
    String? category,
    int? lastVisit,
  }) async {
    try {
      final resp = await api.recommend(
        limit: limit,
        category: category,
        lastVisit: lastVisit,
      );
      final root = resp.data as Map<String, dynamic>? ?? {};
      List<dynamic> raw = [];

      // 适配多种响应格式
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

      final hasMore = items.length == limit;
      debugPrint('VideoRepository.fetchRecommend: limit=$limit items=${items.length}');
      return PagedResult(items: items, page: 1, pageSize: limit, hasMore: hasMore);
    } catch (e) {
      debugPrint('VideoRepository.fetchRecommend: error=$e');
      return PagedResult(items: [], page: 1, pageSize: limit, hasMore: false);
    }
  }
}
