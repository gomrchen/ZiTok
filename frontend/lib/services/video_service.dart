import 'package:dio/dio.dart';

class VideoService {
  final Dio dio;
  VideoService(this.dio);

  Future<Response> feed({required int vid}) {
    return dio.get('/api/video/feed', queryParameters: {'vid': vid});
  }

  Future<Response> popular() {
    return dio.get('/api/video/popular');
  }

  Future<Response> search({required String content, int pages = 1, int size = 20}) {
    return dio.post('/api/video/search', data: {
      'content': content,
      'pages': pages,
      'size': size,
    });
  }

  Future<Response> publish({required String videoUrl, required String coverUrl, String? title, String? intro}) {
    return dio.post('/api/video/auth/publish', data: {
      'video_url': videoUrl,
      'cover_url': coverUrl,
      if (title != null) 'title': title,
      if (intro != null) 'intro': intro,
    });
  }

  Future<Response> list({required int uid}) {
    return dio.get('/api/video/auth/list', queryParameters: {'uid': uid});
  }
}