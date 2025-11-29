// 文件路径: lib/models/social_models.dart

import '../utils/url_utils.dart'; // 如果没有这个文件，可以暂时注释掉这一行，改用下方的备用逻辑

abstract class Conversation {
  String get id;
  String get name;
  String get avatarUrl;
  bool get isGroup;
}

class Friend implements Conversation {
  @override final String id;
  @override final String name;
  @override final String avatarUrl;
  final bool online;

  const Friend({
    required this.id,
    required this.name,
    required this.avatarUrl,
    this.online = false,
  });

  @override bool get isGroup => false;

  factory Friend.fromMergedData(Map<String, dynamic> userInfo, int status) {
    String? rawAvatar = (userInfo['avatar'] ?? userInfo['avatar_url']) as String?;

    // 如果你有 UrlUtils 工具类，请使用它；如果没有，请直接用 rawAvatar ?? ''
    String finalAvatar = '';
    if (rawAvatar != null && rawAvatar.isNotEmpty) {
      // 尝试使用工具类处理
      try {
        finalAvatar = UrlUtils.resolveStorageUrl(rawAvatar, defaultDir: 'avatars');
      } catch (e) {
        finalAvatar = rawAvatar;
      }
    }

    return Friend(
      id: (userInfo['id'] ?? '').toString(),
      name: (userInfo['username'] ?? userInfo['nickname'] ?? '未知用户').toString(),
      avatarUrl: finalAvatar,
      online: status == 1,
    );
  }
}

class ChatRoom implements Conversation {
  @override final String id;
  @override final String name;
  @override final String avatarUrl;
  final int creatorId;
  final int type;

  const ChatRoom({
    required this.id,
    required this.name,
    required this.creatorId,
    required this.type,
    this.avatarUrl = '',
  });

  @override bool get isGroup => true;

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: (json['id'] ?? '').toString(),
      name: json['name'] ?? '未知群聊',
      creatorId: json['creator_id'] ?? 0,
      type: json['type'] ?? 2,
    );
  }
}

class ChatMessage {
  final int id;
  final int senderId;
  final int receiverId;
  final int? roomId;
  final String content;
  final bool isRead;
  final int createdAt;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.roomId,
    required this.content,
    this.isRead = false,
    this.createdAt = 0,
  });

  factory ChatMessage.fromSocketJson(Map<String, dynamic> json) {
    final int ts = json['timestamp'] ?? 0;
    final int fromId = json['from'] ?? 0;
    int? parsedRoomId;
    if (json['room_id'] != null) {
      final rId = int.tryParse(json['room_id'].toString()) ?? -1;
      if (rId != -1) {
        parsedRoomId = rId;
      }
    }

    String rawContent = json['content']?.toString() ?? '';
    // 简单的脏数据清洗逻辑
    if (rawContent.startsWith('map[')) {
      try {
        final start = rawContent.indexOf('content:');
        if (start != -1) {
          // 简易清洗，实际情况可能更复杂
          rawContent = rawContent.substring(start + 8).split(' ').first;
        }
      } catch (_) {}
    }

    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch,
      senderId: fromId,
      receiverId: 0,
      roomId: parsedRoomId,
      content: rawContent,
      isRead: false,
      createdAt: ts > 0 ? ts * 1000 : DateTime.now().millisecondsSinceEpoch,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final sId = int.tryParse(json['sender_id'].toString()) ?? 0;
    final rId = int.tryParse(json['receiver_id'].toString()) ?? 0;
    final rmId = json['room_id'] != null ? int.tryParse(json['room_id'].toString()) : null;

    return ChatMessage(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch,
      senderId: sId,
      receiverId: rId,
      roomId: rmId,
      content: json['content'] ?? json['message'] ?? '',
      isRead: json['is_read'] ?? false,
      createdAt: (json['created_at'] != null && json['created_at'] > 0)
          ? json['created_at']
          : DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'room_id': roomId,
      'content': content,
      'is_read': isRead,
      'created_at': createdAt,
    };
  }
}
