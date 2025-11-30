// 文件路径: lib/providers/messaging_provider.dart

import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../repositories/relation_repository.dart';
import '../services/socket_service.dart';
import '../services/user_session.dart';
import '../models/social_models.dart';

/// 消息去重和管理的日志标签
const String _logTag = 'MsgDedup';

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

  // ==================== 消息去重辅助方法 ====================

  /// 生成消息的内容签名（不依赖时间戳，用于去重）
  /// 格式：发送者ID_接收者或房间ID_内容哈希
  String _contentSignature(ChatMessage msg) {
    final target = msg.roomId ?? msg.receiverId;
    // 使用内容的简单哈希避免过长
    final contentHash = msg.content.hashCode.abs();
    return '${msg.senderId}_${target}_$contentHash';
  }

  /// 合并消息列表，去重并按时间排序
  /// 服务器消息（正数ID）优先于本地临时消息（负数ID）
  List<ChatMessage> _mergeAndDedup(List<ChatMessage> serverMsgs, List<ChatMessage> localMsgs) {
    final Map<String, ChatMessage> merged = {};

    // 先添加服务器消息（优先级高）
    for (var msg in serverMsgs) {
      final sig = _contentSignature(msg);
      merged[sig] = msg;
      developer.log('[$_logTag] 添加服务器消息: id=${msg.id}, sig=$sig, content="${msg.content.substring(0, msg.content.length > 20 ? 20 : msg.content.length)}"', name: _logTag);
    }

    // 再添加本地消息（只有没有对应服务器消息时才添加）
    for (var msg in localMsgs) {
      final sig = _contentSignature(msg);
      if (!merged.containsKey(sig)) {
        merged[sig] = msg;
        developer.log('[$_logTag] 添加本地消息: id=${msg.id}, sig=$sig', name: _logTag);
      } else {
        developer.log('[$_logTag] 跳过重复本地消息: id=${msg.id}, sig=$sig（已有服务器消息）', name: _logTag);
      }
    }

    // 转为列表并按时间排序
    final result = merged.values.toList();
    result.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    developer.log('[$_logTag] 合并结果: 服务器=${serverMsgs.length}, 本地=${localMsgs.length}, 合并后=${result.length}', name: _logTag);
    return result;
  }

  // ==================== 以上是消息去重辅助方法 ====================

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

    // 统一从 UserSession 获取 token
    final token = userSession.accessToken;
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
            '[_handleHistoryMessage] 消息[$i] tryParse成功: content="${msg.content}", from=${msg.senderId}, createdAt=${msg.createdAt}',
            name: 'MsgTime',
          );
        } else {
          developer.log('[_handleHistoryMessage] 消息[$i] tryParse返回null', name: 'Chat');
        }

        // 如果tryParse失败，尝试直接解析
        if (msg == null && item is Map) {
          msg = ChatMessage.fromJson(Map<String, dynamic>.from(item));
          developer.log(
            '[_handleHistoryMessage] 消息[$i] fromJson成功: content="${msg.content}", createdAt=${msg.createdAt}',
            name: 'MsgTime',
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
    developer.log('[$_logTag] ========== 开始合并历史消息 ==========', name: _logTag);

    // 使用新的去重方法合并消息
    serverMsgMap.forEach((key, serverMsgs) {
      final localMsgs = _messages[key] ?? [];
      developer.log('[$_logTag] 会话[$key]: 服务器消息=${serverMsgs.length}, 本地消息=${localMsgs.length}', name: _logTag);

      // 使用统一的合并去重方法
      _messages[key] = _mergeAndDedup(serverMsgs, localMsgs);
    });

    // 处理本地有但服务器没有返回的会话（保留本地消息并排序）
    for (var key in _messages.keys.toList()) {
      if (!serverMsgMap.containsKey(key)) {
        final localMsgs = _messages[key]!;
        developer.log('[$_logTag] 会话[$key]: 服务器无数据，保留本地消息=${localMsgs.length}', name: _logTag);
        localMsgs.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      }
    }

    developer.log('[$_logTag] ========== 合并历史消息完成 ==========', name: _logTag);

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

      // 使用统一的内容签名进行去重
      final newMsgSig = _contentSignature(msg);
      developer.log('[$_logTag] 收到单条消息: id=${msg.id}, sig=$newMsgSig', name: _logTag);

      // 查找是否有匹配的临时消息（负数ID）或重复消息
      final existingIndex = list.indexWhere((m) {
        // 精确ID匹配（仅当两者都是服务器消息时）
        if (m.id > 0 && msg.id > 0 && m.id == msg.id) return true;
        // 内容签名匹配（用于临时消息替换和去重）
        return _contentSignature(m) == newMsgSig;
      });

      if (existingIndex >= 0) {
        final existing = list[existingIndex];
        developer.log('[$_logTag] 找到匹配消息: existingId=${existing.id}, newId=${msg.id}', name: _logTag);

        // 如果已存在的是临时消息（负数ID），用服务器消息替换
        if (existing.id < 0 && msg.id > 0) {
          developer.log('[$_logTag] 替换临时消息为服务器消息', name: _logTag);
          list[existingIndex] = msg;
          list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          notifyListeners();
          _saveHistoryToHive();
        } else {
          developer.log('[$_logTag] 跳过重复消息', name: _logTag);
        }
        // 否则是重复消息，忽略
      } else {
        // 新消息，添加并排序
        developer.log('[$_logTag] 添加新消息到列表', name: _logTag);
        list.add(msg);
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        notifyListeners();
        _saveHistoryToHive();
      }
    } catch (e) {
      developer.log('[$_logTag] 处理单条消息异常: $e', name: _logTag);
    }
  }

  void sendMessage(String conversationId, String text) {
    final uid = currentUid;
    if (uid == null) return;

    final int targetId = int.tryParse(conversationId) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    final Map<String, dynamic> socketPayload = {
      'content': text,
      'room_id': _activeIsGroup ? targetId : -1,
      'type': _activeIsGroup ? 'group' : 'private',
      'from': uid,
      'timestamp': now ~/ 1000,
    };

    if (!_activeIsGroup) {
      socketPayload['to_user'] = targetId;
    }

    _socketService.send(socketPayload);

    // 使用负数ID标记临时消息，避免与服务器ID冲突
    final tempMsg = ChatMessage(
      id: -now, // 负数ID表示本地临时消息
      senderId: uid,
      receiverId: _activeIsGroup ? 0 : targetId,
      roomId: _activeIsGroup ? targetId : null,
      content: text,
      isRead: true,
      createdAt: now,
    );

    final list = _messages.putIfAbsent(conversationId, () => []);
    list.add(tempMsg);
    // 发送后也要排序，保持时间顺序
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));

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

        // 加载后排序，确保时间顺序正确
        msgs.sort((a, b) => a.createdAt.compareTo(b.createdAt));
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
