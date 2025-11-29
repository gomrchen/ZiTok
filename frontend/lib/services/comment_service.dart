import 'package:dio/dio.dart';

class CommentService {
  final Dio dio;
  CommentService(this.dio);



  Future<Response> commentList({required int videoId, int pages = 1, int size = 20}) {
    return dio.get('/video/comments',queryParameters: {'video_id': videoId, 'page': pages, 'size': size});
  }
  Future<Response> addComment({required int videoId, int parentId=-1, String content=''}) {
    // 将 Map 数据包装在 FormData.fromMap 中
    final formData = FormData.fromMap({
      'video_id': videoId,
      'parent_id': parentId,
      'content': content,
    });
    // dio 在发送 FormData 时，会自动将 Content-Type 设置为 'multipart/form-data'
    // 这几乎是所有后端框架都能正确解析的格式。
    return dio.post('/video/comment', data: formData);
  }
  Future<Response> deleteComment({required String videoId,required String commentId}) {
    final formData = FormData.fromMap({
      'video_id': videoId,
      'comment_id': commentId,
    });
    return dio.delete('/comment/delete', data: formData);
  }
}
