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

  Future<Response> search({required String content,String? username,int?from_date,int?to_date, int pages = 1, int size = 20}) {
    return dio.post('/api/video/search', data: {
      'keywords': content,
      'page_num': pages,
      'page_size': size,
      'username': username,
      'from_date': from_date,
      'to_date': to_date,
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
