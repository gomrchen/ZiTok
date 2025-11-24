import 'package:dio/dio.dart';

class VideoService {
  final Dio dio;
  VideoService(this.dio);

  Future<Response> list({String? userId, int page = 1, int size = 20}) {
    final String uidOrTs = (userId != null && userId.isNotEmpty)
        ? userId
        : DateTime.now().millisecondsSinceEpoch.toString();
    return dio.get('/video/list', queryParameters: {
      'user_id': uidOrTs,
      'page': page,
      'size': size,
    });
  }

  Future<Response> hot({int pageSize = 20, int pageNum = 1}) {
    return dio.get('/video/hot', queryParameters: {
      'page_size': pageSize,
      'page_num': pageNum,
    });
  }

  Future<Response> detail({required String videoId, int page = 1, int size = 10}) {
    return dio.get('/video/1', queryParameters: {
      'video_id': videoId,
      'page': page,
      'size': size,
    });
  }

  Future<Response> like({required String videoId}) {
    return dio.post('/video/$videoId/like');
  }

  Future<Response> visit({required String videoId}) {
    return dio.post('/video/$videoId/visit');
  }

  Future<Response> publish({required String videoUrl, required String coverUrl, String? title, String? description, String? userId}) {
    final form = FormData.fromMap({
      'video_data': MultipartFile.fromString(videoUrl),
      'title': title,
      'description': description,
      'user_id': userId,
    });
    return dio.post('/video/publish', data: form);
  }

  Future<Response> search({required String keywords, int pageSize = 20, int pageNum = 1}) {
    return dio.post('/video/search', data: {
      'keywords': keywords,
      'page_size': pageSize,
      'page_num': pageNum,
    });
  }

  Future<Response> delete({required String videoId, String? userId}) {
    return dio.delete('/video/1', queryParameters: {
      'video_id': videoId,
      if (userId != null) 'user_id': userId,
    });
  }
}
