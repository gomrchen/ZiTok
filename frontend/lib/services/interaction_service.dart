import 'package:dio/dio.dart';

class InteractionService {
  final Dio dio;
  InteractionService(this.dio);

  Future<Response> like({int? videoId, int? commentId}) {
    return dio.post('/api/interaction/auth/like', data: {
      if (videoId != null) 'video_id': videoId,
      if (commentId != null) 'comment_id': commentId,
    });
  }

  Future<Response> dislike({int? videoId, int? commentId}) {
    return dio.post('/api/interaction/auth/dislike', data: {
      if (videoId != null) 'video_id': videoId,
      if (commentId != null) 'comment_id': commentId,
    });
  }

  Future<Response> likeList({required int pageSize, required int pageNum}) {
    return dio.post('/api/interaction/auth/like-list', data: {
      'page_size': pageSize,
      'page_num': pageNum,
    });
  }

  Future<Response> comment({required int videoId, required String content, int? rootId, int? replyId}) {
    return dio.post('/api/interaction/auth/comment', data: {
      'video_id': videoId,
      'content': content,
      if (rootId != null) 'root_id': rootId,
      if (replyId != null) 'reply_id': replyId,
    });
  }

  Future<Response> commentList({required int videoId, required int pageSize, required int pageNum}) {
    return dio.post('/api/interaction/auth/comment-list', data: {
      'video_id': videoId,
      'page_size': pageSize,
      'page_num': pageNum,
    });
  }

  Future<Response> deleteComment({required int commentId}) {
    return dio.post('/api/interaction/auth/delete-comment', data: {
      'comment_id': commentId,
    });
  }
}