import 'package:dio/dio.dart';

/// 笔记服务 - 对接后端笔记模块API
/// API基础路径: /api/v1/note/
class NotesService {
  final Dio dio;
  NotesService(this.dio);

  /// 获取视频关联的笔记列表
  Future<Response> getVideoNotes({
    required int videoId,
    int page = 1,
    int pageSize = 10,
  }) {
    return dio.get('/note/video', queryParameters: {
      'video_id': videoId,
      'page': page,
      'page_size': pageSize,
    });
  }

  /// 获取用户的笔记列表
  Future<Response> getUserNotes({
    required int userId,
    int page = 1,
    int pageSize = 10,
  }) {
    return dio.get('/note/user', queryParameters: {
      'user_id': userId,
      'page': page,
      'page_size': pageSize,
    });
  }

  /// 创建笔记
  Future<Response> create({
    required int videoId,
    required String title,
    required String content,
    List<String> imageUrls = const [],
    int seconds = 0,
  }) {
    return dio.post('/note/create', data: {
      'video_id': videoId,
      'title': title,
      'content': content,
      'imageUrls': imageUrls,
      'seconds': seconds,
    });
  }

  /// 删除笔记
  Future<Response> delete({required int noteId}) {
    return dio.post('/note/delete', data: {
      'noteId': noteId,
    });
  }

  /// 点赞/取消点赞笔记（后端自动判断操作类型）
  Future<Response> like({required int noteId}) {
    return dio.post('/note/like', data: { 
      'noteId': noteId,
    });
  }

  /// 收藏/取消收藏笔记（后端自动判断操作类型）
  Future<Response> favorite({required int noteId}) {
    return dio.post('/note/favorite', data: {
      'noteId': noteId,
    });
  }
}