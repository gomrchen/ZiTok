import 'package:dio/dio.dart';

/// 笔记服务（前端新增模块），用于视频关联的时间戳笔记
/// 后端暂未提供正式实现，本模块在开发环境进行本地短路，在非开发环境按 REST 约定调用 /api/notes/* 路由
class NotesService {
  final Dio dio;
  NotesService(this.dio);

  Future<Response> list({required String videoId}) {
    return dio.get('/api/notes/list', queryParameters: {'video_id': videoId});
  }

  Future<Response> create({required String videoId, required String title, required String content, required int seconds}) {
    return dio.post('/api/notes/create', data: {
      'video_id': videoId,
      'title': title,
      'content': content,
      'seconds': seconds,
    });
  }

  Future<Response> delete({required String noteId}) {
    return dio.post('/api/notes/delete', data: {'note_id': noteId});
  }
}