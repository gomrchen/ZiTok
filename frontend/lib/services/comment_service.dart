import 'package:dio/dio.dart';

class CommentService {
  final Dio dio;
  CommentService(this.dio);



  Future<Response> commentList({required int videoId, int pages = 1, int size = 20}) {
    return dio.get('/video/comments',queryParameters: {'video_id': videoId, 'page': pages, 'size': size});
  }

  /// 短剧：评论挂 episode_id（推荐）
  Future<Response> episodeCommentList({required int episodeId, int page = 1, int size = 20}) {
    return dio.get('/episode/$episodeId/comments', queryParameters: {'page': page, 'size': size});
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

  Future<Response> addEpisodeComment({required int episodeId, int parentId = -1, String content = ''}) {
    return dio.post('/episode/$episodeId/comment', data: {
      'content': content,
      if (parentId > 0) 'parent_id': parentId,
    });
  }

  /// 点赞切换；成功 data: {liked, like_count}
  Future<Response> likeEpisode({required int episodeId}) {
    return dio.post('/episode/$episodeId/like');
  }

  /// 查询当前用户是否已点赞；data: {liked, like_count}
  Future<Response> episodeLikeStatus({required int episodeId}) {
    return dio.get('/episode/$episodeId/like');
  }
  Future<Response> deleteComment({required String videoId,required String commentId}) {
    final formData = FormData.fromMap({
      'video_id': videoId,
      'comment_id': commentId,
    });
    return dio.delete('/comment/delete', data: formData);
  }
}
