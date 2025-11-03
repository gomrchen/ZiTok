import 'package:dio/dio.dart';

class RelationService {
  final Dio dio;
  RelationService(this.dio);

  Future<Response> follow({required int targetUid}) {
    return dio.post('/api/relation/auth/follow', data: {'target_uid': targetUid});
  }

  Future<Response> followList({required int uid}) {
    return dio.get('/api/relation/auth/follow-list', queryParameters: {'uid': uid});
  }

  Future<Response> fansList({required int uid}) {
    return dio.get('/api/relation/auth/fans-list', queryParameters: {'uid': uid});
  }

  Future<Response> friendsList({required int uid}) {
    return dio.get('/api/relation/auth/friends-list', queryParameters: {'uid': uid});
  }

  /// 返回一个可用于 WebSocket 的聊天地址
  String chatUrl() {
    final base = dio.options.baseUrl.replaceFirst('http', 'ws');
    return '$base/api/relation/auth/chat';
  }
}