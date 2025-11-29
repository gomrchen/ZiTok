import 'package:dio/dio.dart';

class RelationService {
  final Dio dio;
  RelationService(this.dio);

  Future<Response> follow({required int targetUid}) {
    return dio.post('/api/relation/auth/follow', data: {'target_uid': targetUid});
  }

  // 关注列表 (type=0)
  Future<Response> friendsList({required int userId}) {
    return dio.get('/social/friend/requests', queryParameters: {
      'user_id': userId,
      'type': 0,
    });
  }

  // 粉丝列表 (type=1)
  Future<Response> fansList({required int uid}) {
    return dio.get('/social/friend/requests', queryParameters: {
      'user_id': uid,
      'type': 1,
    });
  }

  Future<Response> getUserInfo({required int userId}) {
    return dio.get('/user/info', queryParameters: {'user_id': userId});
  }

  Future<Response> getChatRooms({required int userId}) {
    return dio.get('/social/chatrooms', queryParameters: {
      'user_id': userId,
      'page': 1,
      'size': 20,
    });
  }

  Future<Response> addFriend({
    required int userId,
    required int friendId,
    String remark = ''
  }) {
    return dio.post('/social/friend', queryParameters: {
      'user_id': userId,
      'friend_id': friendId,
      'remark': remark,
    });
  }

  // 【新增】创建群聊
  // 根据截图，参数需要 name, type, creator_id, member_ids
  Future<Response> createChatRoom({
    required String name,
    required int creatorId,
    required List<int> memberIds,
    int type = 2, // 截图显示 type 为 2
  }) {
    return dio.post('/social/chatroom', data: {
      'name': name,
      'type': type,
      'creator_id': creatorId,
      'member_ids': memberIds,
    });
  }

  String chatUrl() {
    final base = dio.options.baseUrl.replaceFirst('http', 'ws');
    return '$base/api/relation/auth/chat';
  }
}
