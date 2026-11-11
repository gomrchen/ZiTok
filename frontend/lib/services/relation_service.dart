import 'package:dio/dio.dart';

class RelationService {
  final Dio dio;
  RelationService(this.dio);

  // 关注列表兼容旧接口 (type=0 → sender_id)
  Future<Response> friendsList({required int userId}) {
    return dio.get('/social/friend/requests', queryParameters: {
      'user_id': userId,
      'type': 0,
    });
  }

  // 正式好友/关注列表
  Future<Response> getFriends({required int userId}) {
    return dio.get('/social/friends', queryParameters: {
      'user_id': userId,
      'page': 1,
      'size': 50,
    });
  }

  // 粉丝列表 (type=1 → receiver_id)
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
    String remark = '',
  }) {
    return dio.post('/social/friend', queryParameters: {
      'user_id': userId,
      'friend_id': friendId,
      'remark': remark,
    });
  }

  Future<Response> createChatRoom({
    required String name,
    required int creatorId,
    required List<int> memberIds,
    int type = 2,
  }) {
    return dio.post('/social/chatroom', data: {
      'name': name,
      'type': type,
      'creator_id': creatorId,
      'member_ids': memberIds,
    });
  }

  /// 获取群聊详情（含成员）
  Future<Response> getChatRoomMembers({
    required int roomId,
    required int userId,
  }) {
    return dio.get('/social/chatroom/$roomId', queryParameters: {
      'room_id': roomId,
      'user_id': userId,
    });
  }
}
