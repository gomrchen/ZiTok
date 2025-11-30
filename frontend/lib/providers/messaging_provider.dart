// 文件路径: lib/providers/messaging_provider.dart

import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../repositories/relation_repository.dart';
import '../services/socket_service.dart';
import '../services/user_session.dart';
import '../app.dart';
import '../models/social_models.dart';

class MessagingProvider extends ChangeNotifier {
  final RelationRepository? relationRepository;
  final UserSession userSession;
  final SocketService _socketService = SocketService();

  bool _activeIsGroup = false;

  /// 上一次的用户 ID，用于检测用户切换
  String? _lastUserId;

  MessagingProvider({
    this.relationRepository,
    required this.userSession,
  }) {
    // 监听 UserSession 变化，当用户 ID 变化时重置消息数据
    userSession.addListener(_onUserSessionChanged);
    _lastUserId = userSession.userId;
  }

  /// 当 UserSession 变化时调用
  void _onUserSessionChanged() {
    final currentUserId = userSession.userId;

    // 检测用户 ID 是否变化
    if (currentUserId != _lastUserId) {
      _lastUserId = currentUserId;

      // 清空当前数据
      _following = [];
      _followers = [];
      _chatRooms = [];
      _messages.clear();
      notifyListeners();

      // 如果有新用户，重新加载数据
      final uid = currentUid;
      if (uid != null) {
        loadRelationData(uid: uid);
      }
    }
  }

  /// 当前用户 ID（int 类型，用于 API 调用）
  int? get currentUid {
    final userId = userSession.userId;
    if (userId == null || userId.isEmpty) return null;
    return int.tryParse(userId);
  }

  List<Friend> _following = [];
  List<Friend> _followers = [];
  List<ChatRoom> _chatRooms = [];

  final Map<String, List<ChatMessage>> _messages = {};

  List<Friend> get following => List.unmodifiable(_following);
  List<Friend> get followers => List.unmodifiable(_followers);

  List<Friend> get mutualFriends {
    final followerIds = _followers.map((e) => e.id).toSet();
    return _following.where((f) => followerIds.contains(f.id)).toList();
  }

  List<ChatRoom> get chatRooms => List.unmodifiable(_chatRooms);

  List<Conversation> get allConversations {
    final Map<String, Friend> uniqueFriends = {};
    for (var f in _following) {
      uniqueFriends[f.id] = f;
    }
    for (var f in _followers) {
      uniqueFriends[f.id] = f;
    }

    final List<Conversation> list = [];
    list.addAll(uniqueFriends.values);
    list.addAll(_chatRooms);
    return list;
  }

  List<ChatMessage> messagesFor(String conversationId) {
    return List.unmodifiable(_messages[conversationId.toString()] ?? const []);
  }

  Conversation? conversationById(String id, {bool? isGroup}) {
    if (isGroup == true) {
      try {
        return _chatRooms.firstWhere((r) => r.id == id);
      } catch (_) {
        return null;
      }
    }

    final allFriends = {...mutualFriends, ..._following, ..._followers};

    if (isGroup == false) {
      try {
        return allFriends.firstWhere((f) => f.id == id);
      } catch (_) {
        return null;
      }
    }

    try {
      return _chatRooms.firstWhere((r) => r.id == id);
    } catch (_) {
      // Not found in chat rooms
    }

    try {
      return allFriends.firstWhere((f) => f.id == id);
    } catch (_) {
      // Not found in friends
    }

    return null;
  }

  Friend? friendById(String id) {
    final c = conversationById(id, isGroup: false);
    if (c is Friend) return c;
    return null;
  }

  List<Conversation> searchConversations(String query) {
    if (query.isEmpty) return allConversations;
    final q = query.trim().toLowerCase();

    return allConversations.where((c) {
      try {
        final String name = (c.name).toString().toLowerCase();
        final String id = (c.id).toString();
        return name.contains(q) || id.contains(q);
      } catch (_) {
        return false;
      }
    }).toList();
  }

  void logout() {
    _socketService.disconnect();
    _messages.clear();
    _following = [];
    _followers = [];
    _chatRooms = [];
    notifyListeners();
  }

  /// 初始化消息服务
  ///
  /// 使用 UserSession 中的用户 ID 初始化
  Future<void> initFromSession() async {
    final uid = currentUid;
    if (uid == null) return;

    await _loadLocalHistory();
    await loadRelationData(uid: uid);
    connectGlobal();
  }

  /// 使用指定的用户 ID 初始化（用于兼容旧代码）
  Future<void> init(int uid) async {
    final currentId = currentUid;
    if (currentId == uid) return;

    if (currentId != null && currentId != uid) {
      logout();
    }

    await _loadLocalHistory();
    await loadRelationData(uid: uid);
    connectGlobal();
  }

  void connectGlobal() {
    _connect(roomId: '-1', targetId: null);
  }

  void connectToChat({required String id, required bool isGroup}) {
    _activeIsGroup = isGroup;

    if (isGroup) {
      _connect(roomId: id, targetId: null);
    } else {
      _connect(roomId: '-1', targetId: id);
    }
  }

  void _connect({required String roomId, String? targetId}) {
    if (currentUid == null || relationRepository == null) return;

    final token = AppBootstrap.prefs.getString('access_token');
    if (token == null || token.isEmpty) return;

    final baseUrl = _getWsBaseUrl();
    final Map<String, dynamic> params = {
      'token': token,
      'room_id': roomId,
    };
    if (targetId != null) {
      params['to_user'] = targetId;
    }

    final uri = Uri.parse(baseUrl).replace(queryParameters: params);

    _socketService.disconnect();
    _socketService.connect(uri.toString());

    _socketService.onMessage = (dynamic rawData) {
      developer.log(
        '[MessagingProvider] onMessage收到数据: ${rawData.runtimeType}',
        name: 'Chat',
      );

      Map<String, dynamic>? data;

      // 尝试将rawData转换为Map
      if (rawData is Map) {
        data = Map<String, dynamic>.from(rawData);
        developer.log('[MessagingProvider] rawData是Map类型', name: 'Chat');
      } else if (rawData is String) {
        final trimmed = rawData.trim();
        developer.log(
          '[MessagingProvider] rawData是String: ${trimmed.substring(0, trimmed.length > 200 ? 200 : trimmed.length)}',
          name: 'Chat',
        );
        // 处理Go map格式的字符串（支持换行符）
        if (trimmed.startsWith('map[')) {
          data = parseGoMapString(trimmed);
          developer.log('[MessagingProvider] 解析Go map结果: $data', name: 'Chat');
        }
      }

      if (data == null) {
        developer.log('[MessagingProvider] data为null，跳过处理', name: 'Chat');
        return;
      }

      final type = data['type'];
      developer.log('[MessagingProvider] 消息类型: $type', name: 'Chat');

      if (type == 'history') {
        final messages = data['messages'];
        developer.log(
          '[MessagingProvider] 收到history消息，messages类型: ${messages.runtimeType}, 长度: ${messages is List ? messages.length : "N/A"}',
          name: 'Chat',
        );
        _handleHistoryMessage(messages);
      } else if (data.containsKey('content') && data.containsKey('from')) {
        _handleSingleMessage(data);
      }
    };
  }

  void _handleHistoryMessage(dynamic rawMessages) {
    final uid = currentUid;
    if (rawMessages == null || uid == null) {
      developer.log('[_handleHistoryMessage] rawMessages或uid为null', name: 'Chat');
      return;
    }

    // 确保rawMessages是List类型
    List<dynamic> messageList;
    if (rawMessages is List) {
      messageList = rawMessages;
    } else {
      developer.log('[_handleHistoryMessage] rawMessages不是List: ${rawMessages.runtimeType}', name: 'Chat');
      return;
    }

    developer.log('[_handleHistoryMessage] 开始处理 ${messageList.length} 条消息', name: 'Chat');

    final Map<String, List<ChatMessage>> serverMsgMap = {};

    for (int i = 0; i < messageList.length; i++) {
      final item = messageList[i];
      try {
        // 调试日志：打印每条消息的原始数据
        developer.log(
          '[_handleHistoryMessage] 消息[$i] 类型: ${item.runtimeType}, 值: ${item.toString().substring(0, item.toString().length > 300 ? 300 : item.toString().length)}',
          name: 'Chat',
        );

        ChatMessage? msg;

        // 使用tryParse自动检测并解析各种格式
        msg = ChatMessage.tryParse(item);

        if (msg != null) {
          developer.log(
            '[_handleHistoryMessage] 消息[$i] tryParse成功: content="${msg.content}", from=${msg.senderId}',
            name: 'Chat',
          );
        } else {
          developer.log('[_handleHistoryMessage] 消息[$i] tryParse返回null', name: 'Chat');
        }

        // 如果tryParse失败，尝试直接解析
        if (msg == null && item is Map) {
          msg = ChatMessage.fromJson(Map<String, dynamic>.from(item));
          developer.log(
            '[_handleHistoryMessage] 消息[$i] fromJson成功: content="${msg.content}"',
            name: 'Chat',
          );
        }

        if (msg == null) {
          developer.log('[_handleHistoryMessage] 消息[$i] 解析失败，跳过', name: 'Chat');
          continue;
        }

        String key;
        if (msg.roomId != null && msg.roomId != -1) {
          key = msg.roomId.toString();
        } else {
          key = (msg.senderId == uid)
              ? msg.receiverId.toString()
              : msg.senderId.toString();
        }
        if (!serverMsgMap.containsKey(key)) {
          serverMsgMap[key] = [];
        }
        serverMsgMap[key]!.add(msg);
      } catch (e) {
        developer.log('[_handleHistoryMessage] 消息[$i] 解析异常: $e', name: 'Chat');
      }
    }

    developer.log('[_handleHistoryMessage] 解析完成，共 ${serverMsgMap.length} 个会话', name: 'Chat');

    serverMsgMap.forEach((key, serverMsgs) {
      final localMsgs = _messages[key] ?? [];
      final List<ChatMessage> mergedList = [...serverMsgs];

      for (var localMsg in localMsgs) {
        if (localMsg.id > 1000000000000) {
          final exists = serverMsgs.any((sm) =>
              sm.createdAt == localMsg.createdAt &&
              sm.content == localMsg.content);
          if (!exists) mergedList.add(localMsg);
        }
      }
      mergedList.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _messages[key] = mergedList;
    });

    notifyListeners();
    _saveHistoryToHive();
  }

  void _handleSingleMessage(Map<String, dynamic> data) {
    try {
      final msg = ChatMessage.fromSocketJson(data);

      String key;
      if (msg.roomId != null) {
        key = msg.roomId.toString();
      } else {
        key = msg.senderId.toString();
      }

      if (!_messages.containsKey(key)) {
        _messages[key] = [];
      }
      final list = _messages[key]!;

      final isDuplicate = list.any((m) =>
          (m.id == msg.id) ||
          (m.senderId == msg.senderId &&
              m.content == msg.content &&
              (m.createdAt - msg.createdAt).abs() < 1000));

      if (!isDuplicate) {
        list.add(msg);
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        notifyListeners();
        _saveHistoryToHive();
      }
    } catch (_) {
      // Socket message error, ignore
    }
  }

  void sendMessage(String conversationId, String text) {
    final uid = currentUid;
    if (uid == null) return;

    final int targetId = int.tryParse(conversationId) ?? 0;

    final Map<String, dynamic> socketPayload = {
      'content': text,
      'room_id': _activeIsGroup ? targetId : -1,
      'type': _activeIsGroup ? 'group' : 'private',
      'from': uid,
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };

    if (!_activeIsGroup) {
      socketPayload['to_user'] = targetId;
    }

    _socketService.send(socketPayload);

    final tempMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch,
      senderId: uid,
      receiverId: _activeIsGroup ? 0 : targetId,
      roomId: _activeIsGroup ? targetId : null,
      content: text,
      isRead: true,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    final list = _messages.putIfAbsent(conversationId, () => []);
    list.add(tempMsg);

    notifyListeners();
    _saveHistoryToHive();
  }

  Future<String> addFriendAction(String targetIdStr, String remark) async {
    final uid = currentUid;
    if (relationRepository == null || uid == null) return "未登录";
    final targetId = int.tryParse(targetIdStr);
    if (targetId == null) return "ID无效";

    final result =
        await relationRepository!.sendFriendRequest(uid, targetId, remark);
    if (result['success'] == true) {
      loadRelationData(uid: uid);
      return "OK";
    } else {
      return result['message'] ?? "失败";
    }
  }

  Future<String> createGroupAction(
      String groupName, List<int> selectedUserIds) async {
    final uid = currentUid;
    if (relationRepository == null || uid == null) return "未登录";

    final result = await relationRepository!
        .createGroup(groupName, uid, selectedUserIds);

    if (result['success'] == true) {
      await loadRelationData(uid: uid);
      return "OK";
    } else {
      return result['msg'];
    }
  }

  String _getWsBaseUrl() {
    final baseUrl = relationRepository!.api.dio.options.baseUrl;
    String wsBaseUrl = baseUrl.startsWith('https')
        ? baseUrl.replaceFirst('https', 'wss')
        : baseUrl.replaceFirst('http', 'ws');
    if (!wsBaseUrl.endsWith('/')) {
      wsBaseUrl += '/';
    }
    return '${wsBaseUrl}social/ws/connect';
  }

  Future<void> _loadLocalHistory() async {
    try {
      final box = await Hive.openBox('messages_box');
      for (var key in box.keys) {
        final List dynamicList = box.get(key) ?? [];
        final List<ChatMessage> msgs = [];

        for (var e in dynamicList) {
          try {
            // 使用tryParse自动检测并解析各种格式
            final msg = ChatMessage.tryParse(e);
            if (msg != null) {
              msgs.add(msg);
            } else if (e is Map) {
              // 回退到直接解析Map
              msgs.add(ChatMessage.fromJson(Map<String, dynamic>.from(e)));
            }
          } catch (_) {
            // 单条消息解析失败，跳过
          }
        }

        _messages[key.toString()] = msgs;
      }
      notifyListeners();
    } catch (_) {
      // Load error, ignore
    }
  }

  void _saveHistoryToHive() {
    final box = Hive.box('messages_box');
    _messages.forEach((key, list) {
      final jsonList = list.map((e) => e.toMap()).toList();
      box.put(key, jsonList);
    });
  }

  Future<void> loadRelationData({required int uid}) async {
    if (relationRepository == null) return;
    try {
      final results = await Future.wait([
        relationRepository!.getFollowingList(uid),
        relationRepository!.getFollowersList(uid),
        relationRepository!.getChatRooms(uid),
      ]);
      _following = results[0] as List<Friend>;
      _followers = results[1] as List<Friend>;
      _chatRooms = results[2] as List<ChatRoom>;
      notifyListeners();
    } catch (_) {
      // Load error, ignore
    }
  }

  @override
  void dispose() {
    userSession.removeListener(_onUserSessionChanged);
    super.dispose();
  }
}
