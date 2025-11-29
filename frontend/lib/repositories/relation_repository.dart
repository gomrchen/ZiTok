import '../services/relation_service.dart';
import '../models/social_models.dart';

class RelationRepository {
  final RelationService api;

  RelationRepository({required this.api});

  /// 内部工具：批量获取详情
  /// [idKey] 对方ID在JSON中的字段名 (sender_id 或 receiver_id)
  Future<List<Friend>> _fetchDetails(List listData, String idKey) async {
    final futures = listData.map((item) async {
      // 获取目标ID (可以是好友，也可以是自己)
      final targetId = item[idKey];
      final int onlineStatus = item['status'] ?? 0;

      if (targetId == null) return null;

      // 【修改】这里不做过滤，允许 targetId == myUid (保留文件传输助手/自己给自己发消息功能)

      try {
        // 调用API获取头像昵称
        final userResponse = await api.getUserInfo(userId: targetId);
        final userData = userResponse.data;

        if (userData['code'] == '10000' || userData['code'] == 10000) {
          return Friend.fromMergedData(userData['data'], onlineStatus);
        }
      } catch (e) {
        // Ignore error silently
      }
      return null;
    });

    final results = await Future.wait(futures);
    return results.whereType<Friend>().toList();
  }

  /// 获取关注列表 (我的关注)
  /// 对应接口: /social/friend/requests?type=0
  Future<List<Friend>> getFollowingList(int uid) async {
    try {
      final response = await api.friendsList(userId: uid);
      final data = response.data;

      if (data['code'] == '10000' || data['code'] == 10000) {
        // 【关键】在 type=0 列表中，sender_id 是对方 ID
        return await _fetchDetails(data['data'] ?? [], 'sender_id');
      }
    } catch (e) {
      // Ignore error silently
    }
    return [];
  }

  /// 获取粉丝列表 (关注我的)
  /// 对应接口: /social/friend/requests?type=1
  Future<List<Friend>> getFollowersList(int uid) async {
    try {
      final response = await api.fansList(uid: uid);
      final data = response.data;
      if (data['code'] == '10000' || data['code'] == 10000) {
        // 假设 type=1 时，receiver_id 是粉丝 ID
        return await _fetchDetails(data['data'] ?? [], 'receiver_id');
      }
    } catch (e) {
      // Ignore error silently
    }
    return [];
  }

  Future<List<ChatRoom>> getChatRooms(int userId) async {
    try {
      final response = await api.getChatRooms(userId: userId);
      final data = response.data;
      if (data['code'] == '10000' || data['code'] == 10000) {
        final List list = data['data'] ?? [];
        return list.map((e) => ChatRoom.fromJson(e)).toList();
      }
    } catch (e) {
      // Ignore error silently
    }
    return [];
  }

  Future<Map<String, dynamic>> sendFriendRequest(int myUid, int targetUid, String remark) async {
    try {
      final response = await api.addFriend(userId: myUid, friendId: targetUid, remark: remark);
      final data = response.data;
      final code = data['code']?.toString();
      final msg = data['message'] ?? '未知错误';

      if (code == '10000') {
        return {'success': true, 'message': '关注成功'};
      } else if (code == '50000') {
        return {'success': false, 'message': '已经关注对方'};
      } else {
        return {'success': false, 'message': '操作失败: $msg'};
      }
    } catch (e) {
      return {'success': false, 'message': '网络错误: $e'};
    }
  }

  // 【新增】创建群聊逻辑
  Future<Map<String, dynamic>> createGroup(String name, int creatorId, List<int> memberIds) async {
    try {
      // 截图显示 member_ids 包含了 creator_id (1, 2, 3)，为了保险起见，
      // 如果传入的 memberIds 不包含创建者，我们手动加进去
      final List<int> finalMembers = List.from(memberIds);
      if (!finalMembers.contains(creatorId)) {
        finalMembers.add(creatorId);
      }

      final response = await api.createChatRoom(
          name: name,
          creatorId: creatorId,
          memberIds: finalMembers
      );

      final data = response.data;
      if (data['code'] == '10000' || data['code'] == 10000) {
        return {'success': true, 'msg': '创建成功'};
      } else {
        return {'success': false, 'msg': data['message'] ?? '创建失败'};
      }
    } catch (e) {
      return {'success': false, 'msg': '网络错误: $e'};
    }
  }
}
