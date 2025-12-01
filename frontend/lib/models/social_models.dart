// 文件路径: lib/models/social_models.dart

import '../utils/url_utils.dart';
import '../utils/app_config.dart';

/// 解析Go语言map格式的字符串
/// 例如: "map[content:急急急 from:7 room_id:1 timestamp:1.764435002e+09 type:group]"
/// 返回: {"content": "急急急", "from": "7", "room_id": "1", ...}
///
/// 支持换行符、多余空格等各种格式
Map<String, dynamic>? parseGoMapString(dynamic input) {
  if (input == null) return null;

  String str = input.toString().trim();

  AppConfig.log('[parseGoMapString] 输入: ${str.substring(0, str.length > 200 ? 200 : str.length)}');

  // 检查是否是Go map格式
  if (!str.startsWith('map[') || !str.endsWith(']')) {
    AppConfig.log('[parseGoMapString] 不是Go map格式');
    return null;
  }

  // 去掉 "map[" 和 "]"
  String inner = str.substring(4, str.length - 1);
  if (inner.isEmpty) {
    AppConfig.log('[parseGoMapString] inner为空');
    return null;
  }

  // 将换行符、制表符等替换为空格，然后规范化多余空格
  inner = inner.replaceAll(RegExp(r'[\r\n\t]+'), ' ');
  inner = inner.replaceAll(RegExp(r'\s+'), ' ').trim();

  AppConfig.log('[parseGoMapString] 规范化后: $inner');

  // 已知的所有可能的key（按长度降序排列，避免短key匹配到长key的一部分）
  final knownKeys = [
    'receiver_id', 'sender_id', 'created_at', 'timestamp',
    'room_id', 'to_user', 'content', 'is_read', 'from', 'type', 'id', 'message'
  ];

  // 找到所有key的位置
  final List<MapEntry<int, String>> keyPositions = [];

  for (var key in knownKeys) {
    // 检查开头的情况
    if (inner.startsWith('$key:')) {
      keyPositions.add(MapEntry(0, key));
    }

    // 检查中间的情况（前面有空格）
    int searchStart = 0;
    while (true) {
      final pattern = ' $key:';
      int pos = inner.indexOf(pattern, searchStart);
      if (pos == -1) break;
      keyPositions.add(MapEntry(pos + 1, key)); // +1 跳过空格
      searchStart = pos + pattern.length;
    }
  }

  if (keyPositions.isEmpty) {
    AppConfig.log('[parseGoMapString] 未找到任何已知key');
    return null;
  }

  // 按位置排序
  keyPositions.sort((a, b) => a.key.compareTo(b.key));

  AppConfig.log('[parseGoMapString] 找到keys: ${keyPositions.map((e) => "${e.value}@${e.key}").join(", ")}');

  final Map<String, dynamic> result = {};

  for (int i = 0; i < keyPositions.length; i++) {
    final pos = keyPositions[i].key;
    final key = keyPositions[i].value;
    final valueStart = pos + key.length + 1; // 跳过 "key:"

    int valueEnd;
    if (i + 1 < keyPositions.length) {
      valueEnd = keyPositions[i + 1].key - 1; // 下一个key前面的空格
    } else {
      valueEnd = inner.length;
    }

    if (valueStart <= valueEnd && valueStart < inner.length) {
      final value = inner.substring(valueStart, valueEnd).trim();
      result[key] = value;
      // 特别记录时间戳字段
      if (key == 'timestamp' || key == 'created_at') {
        AppConfig.log('[parseGoMapString] 时间戳字段: $key = "$value"');
      }
    }
  }

  AppConfig.log('[parseGoMapString] 最终结果keys: ${result.keys.toList()}');
  return result.isNotEmpty ? result : null;
}

/// 尝试将任意数据转换为 `Map<String, dynamic>`
/// 支持: Map, Go map格式字符串
Map<String, dynamic>? tryParseToMap(dynamic data) {
  if (data == null) return null;

  // 已经是Map
  if (data is Map) {
    return Map<String, dynamic>.from(data);
  }

  final str = data.toString();

  // 尝试解析Go map格式
  if (str.startsWith('map[')) {
    return parseGoMapString(str);
  }

  return null;
}

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

  /// 从WebSocket消息创建ChatMessage
  /// 支持标准JSON格式和Go map格式字符串
  factory ChatMessage.fromSocketJson(Map<String, dynamic> json) {
    AppConfig.log('[ChatMessage.fromSocketJson] 输入json: $json');

    // 解析消息ID（优先使用服务器ID）
    int msgId = 0;
    if (json['id'] != null) {
      msgId = int.tryParse(json['id'].toString()) ?? 0;
    }

    // 解析timestamp，支持科学计数法
    int createdAtMs = 0;
    final tsValue = json['timestamp'];
    AppConfig.log('[ChatMessage.fromSocketJson] timestamp原始值: $tsValue (${tsValue.runtimeType})');

    if (tsValue != null) {
      int ts = 0;
      if (tsValue is int) {
        ts = tsValue;
        AppConfig.log('[ChatMessage.fromSocketJson] timestamp是int: $ts');
      } else if (tsValue is double) {
        ts = tsValue.toInt();
        AppConfig.log('[ChatMessage.fromSocketJson] timestamp是double: $ts');
      } else {
        // 支持科学计数法字符串，如 "1.764435002e+09"
        final tsStr = tsValue.toString();
        final parsed = double.tryParse(tsStr);
        AppConfig.log('[ChatMessage.fromSocketJson] timestamp是String "$tsStr", 解析为double: $parsed');
        if (parsed != null) {
          ts = parsed.toInt();
        }
      }
      // 将秒级时间戳转为毫秒级
      createdAtMs = _normalizeTimestamp(ts);
      AppConfig.log('[ChatMessage.fromSocketJson] ts=$ts, 规范化后createdAtMs=$createdAtMs');
    }
    // 也检查 created_at 字段
    if (createdAtMs == 0 && json['created_at'] != null) {
      createdAtMs = _normalizeTimestamp(_parseIntField(json['created_at']));
      AppConfig.log('[ChatMessage.fromSocketJson] 使用created_at: $createdAtMs');
    }

    AppConfig.log('[ChatMessage.fromSocketJson] 最终: id=$msgId, createdAtMs=$createdAtMs');

    // 解析fromId
    int fromId = 0;
    if (json['from'] != null) {
      fromId = int.tryParse(json['from'].toString()) ?? 0;
    }

    // 解析room_id
    int? parsedRoomId;
    if (json['room_id'] != null) {
      final rId = int.tryParse(json['room_id'].toString()) ?? -1;
      if (rId != -1) {
        parsedRoomId = rId;
      }
    }

    // 解析content，处理可能嵌套的Go map格式
    String rawContent = '';
    if (json['content'] != null) {
      final contentValue = json['content'];
      if (contentValue is String && contentValue.startsWith('map[')) {
        // content本身是Go map格式，尝试提取其中的content字段
        final nestedMap = parseGoMapString(contentValue);
        if (nestedMap != null && nestedMap['content'] != null) {
          rawContent = nestedMap['content'].toString();
        } else {
          rawContent = contentValue;
        }
      } else {
        rawContent = contentValue.toString();
      }
    }

    return ChatMessage(
      id: msgId > 0 ? msgId : -DateTime.now().millisecondsSinceEpoch, // 无服务器ID时使用负数临时ID
      senderId: fromId,
      receiverId: 0,
      roomId: parsedRoomId,
      content: rawContent,
      isRead: false,
      createdAt: createdAtMs > 0 ? createdAtMs : DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// 解析整数字段（支持int、double、String）
  static int _parseIntField(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    final parsed = double.tryParse(value.toString());
    return parsed?.toInt() ?? 0;
  }

  /// 将时间戳规范化为毫秒级
  /// 如果时间戳小于 10^12（约2001年），认为是秒级时间戳，需要乘以1000
  static int _normalizeTimestamp(int ts) {
    if (ts <= 0) return 0;
    // 10^12 毫秒 = 2001-09-09，如果小于这个值，认为是秒级时间戳
    if (ts < 1000000000000) {
      return ts * 1000;
    }
    return ts;
  }

  /// 从任意数据创建ChatMessage（自动检测格式）
  /// 支持: Map, Go map格式字符串, 普通字符串
  static ChatMessage? tryParse(dynamic data) {
    if (data == null) {
      AppConfig.log('[ChatMessage.tryParse] data为null');
      return null;
    }

    AppConfig.log('[ChatMessage.tryParse] 输入类型: ${data.runtimeType}');

    Map<String, dynamic>? json;

    if (data is Map) {
      json = Map<String, dynamic>.from(data);
      AppConfig.log('[ChatMessage.tryParse] 已是Map类型，keys: ${json.keys.toList()}');
    } else if (data is String) {
      final trimmed = data.trim();
      AppConfig.log('[ChatMessage.tryParse] 是String，开头: ${trimmed.substring(0, trimmed.length > 50 ? 50 : trimmed.length)}');
      // 检查是否是Go map格式（支持换行符在中间的情况）
      if (trimmed.startsWith('map[')) {
        AppConfig.log('[ChatMessage.tryParse] 检测到Go map格式，调用parseGoMapString');
        json = parseGoMapString(trimmed);
      } else {
        AppConfig.log('[ChatMessage.tryParse] 不是Go map格式');
      }
    } else {
      AppConfig.log('[ChatMessage.tryParse] 未知类型: ${data.runtimeType}');
    }

    if (json == null) {
      AppConfig.log('[ChatMessage.tryParse] json为null，解析失败');
      return null;
    }

    AppConfig.log('[ChatMessage.tryParse] 解析后json: $json');

    // 根据字段判断使用哪个解析方法
    // WebSocket消息通常包含 'from' 和 'timestamp' 字段
    if (json.containsKey('from') || json.containsKey('timestamp')) {
      AppConfig.log('[ChatMessage.tryParse] 使用fromSocketJson解析');
      return ChatMessage.fromSocketJson(json);
    } else {
      AppConfig.log('[ChatMessage.tryParse] 使用fromJson解析');
      return ChatMessage.fromJson(json);
    }
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final sId = int.tryParse(json['sender_id'].toString()) ?? 0;
    final rId = int.tryParse(json['receiver_id'].toString()) ?? 0;
    final rmId = json['room_id'] != null ? int.tryParse(json['room_id'].toString()) : null;

    // 处理content字段，可能是Go map格式的字符串
    String rawContent = json['content']?.toString() ?? json['message']?.toString() ?? '';
    int contentTimestamp = 0; // 从content的Go map中提取的时间戳

    if (rawContent.trim().startsWith('map[')) {
      final parsed = parseGoMapString(rawContent);
      if (parsed != null) {
        // 提取真正的内容
        if (parsed['content'] != null) {
          rawContent = parsed['content'].toString();
        }
        // 从Go map中提取时间戳
        if (parsed['timestamp'] != null) {
          final tsStr = parsed['timestamp'].toString();
          final tsDouble = double.tryParse(tsStr);
          if (tsDouble != null) {
            contentTimestamp = tsDouble.toInt();
          }
        }
        AppConfig.log('[ChatMessage.fromJson] content是Go map格式，解析后: content="$rawContent", timestamp=$contentTimestamp');
      }
    }

    // 解析消息ID
    int msgId = _parseIntField(json['id']);

    // 解析时间戳（优先级：content内的timestamp > json的created_at > json的timestamp）
    int createdAtMs = 0;

    // 1. 优先使用从content Go map中提取的timestamp
    if (contentTimestamp > 0) {
      createdAtMs = _normalizeTimestamp(contentTimestamp);
      AppConfig.log('[ChatMessage.fromJson] 使用content内的timestamp: $contentTimestamp -> $createdAtMs');
    }

    // 2. 其次使用json的created_at
    if (createdAtMs == 0) {
      createdAtMs = _normalizeTimestamp(_parseIntField(json['created_at']));
    }

    // 3. 最后检查json的timestamp字段
    if (createdAtMs == 0 && json['timestamp'] != null) {
      createdAtMs = _normalizeTimestamp(_parseIntField(json['timestamp']));
    }

    AppConfig.log('[ChatMessage.fromJson] 最终: id=$msgId, createdAtMs=$createdAtMs');

    return ChatMessage(
      id: msgId > 0 ? msgId : -DateTime.now().millisecondsSinceEpoch, // 无服务器ID时使用负数临时ID
      senderId: sId,
      receiverId: rId,
      roomId: rmId,
      content: rawContent,
      isRead: json['is_read'] ?? false,
      createdAt: createdAtMs > 0 ? createdAtMs : DateTime.now().millisecondsSinceEpoch,
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
