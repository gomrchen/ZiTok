import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/exceptions/api_exception.dart';
import '../../../../core/utils/logger.dart';
import '../models/video_model.dart';

/// 视频数据仓库
/// 负责视频相关的数据获取和操作
class VideoRepository {
  final ApiClient _apiClient;
  
  VideoRepository(this._apiClient);
  
  /// 获取推荐视频列表
  Future<List<VideoModel>> getRecommendedVideos({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      AppLogger.info('获取推荐视频列表: page=$page, pageSize=$pageSize');
      
      final response = await _apiClient.get(
        '/videos/recommended',
        queryParameters: {
          'page': page,
          'page_size': pageSize,
        },
      );
      
      final List<dynamic> data = response.data['data'];
      final videos = data.map((json) => VideoModel.fromJson(json)).toList();
      
      AppLogger.info('获取推荐视频成功: ${videos.length}个视频');
      return videos;
    } catch (e) {
      AppLogger.error('获取推荐视频失败', e);
      throw const ApiException(
        code: 'GET_RECOMMENDED_VIDEOS_FAILED',
        message: '获取推荐视频失败',
      );
    }
  }
  
  /// 获取关注用户的视频
  Future<List<VideoModel>> getFollowingVideos({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      AppLogger.info('获取关注视频列表: page=$page, pageSize=$pageSize');
      
      final response = await _apiClient.get(
        '/videos/following',
        queryParameters: {
          'page': page,
          'page_size': pageSize,
        },
      );
      
      final List<dynamic> data = response.data['data'];
      final videos = data.map((json) => VideoModel.fromJson(json)).toList();
      
      AppLogger.info('获取关注视频成功: ${videos.length}个视频');
      return videos;
    } catch (e) {
      AppLogger.error('获取关注视频失败', e);
      throw const ApiException(
        code: 'GET_FOLLOWING_VIDEOS_FAILED',
        message: '获取关注视频失败',
      );
    }
  }
  
  /// 根据ID获取视频详情
  Future<VideoModel> getVideoById(String videoId) async {
    try {
      AppLogger.info('获取视频详情: videoId=$videoId');
      
      final response = await _apiClient.get('/videos/$videoId');
      final video = VideoModel.fromJson(response.data['data']);
      
      AppLogger.info('获取视频详情成功: ${video.title}');
      return video;
    } catch (e) {
      AppLogger.error('获取视频详情失败', e);
      throw const ApiException(
        code: 'GET_VIDEO_FAILED',
        message: '获取视频详情失败',
      );
    }
  }
  
  /// 搜索视频
  Future<List<VideoModel>> searchVideos({
    required String keyword,
    int page = 1,
    int pageSize = 20,
    String? category,
    List<String>? tags,
  }) async {
    try {
      AppLogger.info('搜索视频: keyword=$keyword, page=$page');
      
      final queryParameters = <String, dynamic>{
        'keyword': keyword,
        'page': page,
        'page_size': pageSize,
      };
      
      if (category != null) {
        queryParameters['category'] = category;
      }
      
      if (tags != null && tags.isNotEmpty) {
        queryParameters['tags'] = tags.join(',');
      }
      
      final response = await _apiClient.get(
        '/videos/search',
        queryParameters: queryParameters,
      );
      
      final List<dynamic> data = response.data['data'];
      final videos = data.map((json) => VideoModel.fromJson(json)).toList();
      
      AppLogger.info('搜索视频成功: ${videos.length}个结果');
      return videos;
    } catch (e) {
      AppLogger.error('搜索视频失败', e);
      throw const ApiException(
        code: 'SEARCH_VIDEOS_FAILED',
        message: '搜索视频失败',
      );
    }
  }
  
  /// 点赞视频
  Future<bool> likeVideo(String videoId) async {
    try {
      AppLogger.info('点赞视频: videoId=$videoId');
      
      final response = await _apiClient.post('/videos/$videoId/like');
      final success = response.data['success'] ?? false;
      
      AppLogger.info('点赞视频${success ? '成功' : '失败'}');
      return success;
    } catch (e) {
      AppLogger.error('点赞视频失败', e);
      throw const ApiException(
        code: 'LIKE_VIDEO_FAILED',
        message: '点赞失败',
      );
    }
  }
  
  /// 取消点赞视频
  Future<bool> unlikeVideo(String videoId) async {
    try {
      AppLogger.info('取消点赞视频: videoId=$videoId');
      
      final response = await _apiClient.delete('/videos/$videoId/like');
      final success = response.data['success'] ?? false;
      
      AppLogger.info('取消点赞视频${success ? '成功' : '失败'}');
      return success;
    } catch (e) {
      AppLogger.error('取消点赞视频失败', e);
      throw const ApiException(
        code: 'UNLIKE_VIDEO_FAILED',
        message: '取消点赞失败',
      );
    }
  }
  
  /// 收藏视频
  Future<bool> favoriteVideo(String videoId) async {
    try {
      AppLogger.info('收藏视频: videoId=$videoId');
      
      final response = await _apiClient.post('/videos/$videoId/favorite');
      final success = response.data['success'] ?? false;
      
      AppLogger.info('收藏视频${success ? '成功' : '失败'}');
      return success;
    } catch (e) {
      AppLogger.error('收藏视频失败', e);
      throw const ApiException(
        code: 'FAVORITE_VIDEO_FAILED',
        message: '收藏失败',
      );
    }
  }
  
  /// 取消收藏视频
  Future<bool> unfavoriteVideo(String videoId) async {
    try {
      AppLogger.info('取消收藏视频: videoId=$videoId');
      
      final response = await _apiClient.delete('/videos/$videoId/favorite');
      final success = response.data['success'] ?? false;
      
      AppLogger.info('取消收藏视频${success ? '成功' : '失败'}');
      return success;
    } catch (e) {
      AppLogger.error('取消收藏视频失败', e);
      throw const ApiException(
        code: 'UNFAVORITE_VIDEO_FAILED',
        message: '取消收藏失败',
      );
    }
  }
  
  /// 上传视频
  Future<VideoModel> uploadVideo({
    required String filePath,
    required String title,
    String? description,
    List<String>? tags,
    List<String>? knowledgePoints,
    String? coverPath,
  }) async {
    try {
      AppLogger.info('上传视频: title=$title');
      
      // 这里应该实现文件上传逻辑
      // 由于涉及FormData，暂时返回模拟数据
      throw UnimplementedError('视频上传功能待实现');
    } catch (e) {
      AppLogger.error('上传视频失败', e);
      throw const ApiException(
        code: 'UPLOAD_VIDEO_FAILED',
        message: '上传视频失败',
      );
    }
  }
  
  /// 删除视频
  Future<bool> deleteVideo(String videoId) async {
    try {
      AppLogger.info('删除视频: videoId=$videoId');
      
      final response = await _apiClient.delete('/videos/$videoId');
      final success = response.data['success'] ?? false;
      
      AppLogger.info('删除视频${success ? '成功' : '失败'}');
      return success;
    } catch (e) {
      AppLogger.error('删除视频失败', e);
      throw const ApiException(
        code: 'DELETE_VIDEO_FAILED',
        message: '删除视频失败',
      );
    }
  }
  
  /// 举报视频
  Future<bool> reportVideo(String videoId, String reason) async {
    try {
      AppLogger.info('举报视频: videoId=$videoId, reason=$reason');
      
      final response = await _apiClient.post(
        '/videos/$videoId/report',
        data: {'reason': reason},
      );
      
      final success = response.data['success'] ?? false;
      
      AppLogger.info('举报视频${success ? '成功' : '失败'}');
      return success;
    } catch (e) {
      AppLogger.error('举报视频失败', e);
      throw const ApiException(
        code: 'REPORT_VIDEO_FAILED',
        message: '举报失败',
      );
    }
  }
}

/// 视频仓库Provider
final videoRepositoryProvider = Provider<VideoRepository>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return VideoRepository(apiClient);
});