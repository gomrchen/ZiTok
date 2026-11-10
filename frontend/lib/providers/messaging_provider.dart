// 文件路径: lib/providers/messaging_provider.dart

// developer.log replaced with AppConfig conditional logging
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../repositories/relation_repository.dart';
import '../services/socket_service.dart';
import '../services/user_session.dart';
import '../models/social_models.dart';
import '../utils/app_config.dart';

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

    // 检测用户 ID 是否变化（含退出登录 → null）
    if (currentUserId != _lastUserId) {
      _lastUserId = currentUserId;

      // 先断旧连接，避免退出后仍带着旧 token 收发
      _socketService.disconnect();
      _userCache.clear();
      _fetchingUserIds.clear();
      _following = [];
      _followers = [];
      _chatRooms = [];
      _messages.clear();
      notifyListeners();

      // 如果有新用户，重新加载并建连
      final uid = currentUid;
      if (uid != null) {
        loadRelationData(uid: uid);
        connectGlobal();
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

  /// 用户信息缓存：key为用户ID，value为用户信息
  final Map<String, Friend> _userCache = {};

  /// 正在获取中的用户ID集合（防止重复请求）
  final Set<String> _fetchingUserIds = {};

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
      AppConfig.log('[$_logTag] 添加服务器消息: id=${msg.id}, sig=$sig');
    }

    // 再添加本地消息（只有没有对应服务器消息时才添加）
    for (var msg in localMsgs) {
      final sig = _contentSignature(msg);
      if (!merged.containsKey(sig)) {
        merged[sig] = msg;
        AppConfig.log('[$_logTag] 添加本地消息: id=${msg.id}, sig=$sig');
      } else {
        AppConfig.log('[$_logTag] 跳过重复本地消息: id=${msg.id}, sig=$sig');
      }
    }

    // 转为列表并按时间排序
    final result = merged.values.toList();
    result.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    AppConfig.log('[$_logTag] 合并结果: 服务器=${serverMsgs.length}, 本地=${localMsgs.length}, 合并后=${result.length}');
    return result;
  }

  // ==================== 以上是消息去重辅助方法 ====================

  List<Friend> get following => List.unmodifiable(_following);
  List<Friend> get followers => List.unmodifiable(_followers);

  /// 检查是否关注了指定用户
  bool isFollowing(String uid) {
    return _following.any((f) => f.id == uid);
  }

  /// 关注或取消关注用户
  Future<bool> toggleFollow(String targetUid) async {
    final uid = currentUid;
    if (uid == null || relationRepository == null) return false;

    final targetId = int.tryParse(targetUid);
    if (targetId == null) return false;

    final wasFollowing = isFollowing(targetUid);

    try {
      if (wasFollowing) {
        // 目前API可能没有取消关注接口，暂时只从本地移除
        _following.removeWhere((f) => f.id == targetUid);
      } else {
        // 调用关注API（使用sendFriendRequest）
        final result = await relationRepository!.sendFriendRequest(uid, targetId, '');
        if (result['success'] != true) {
          AppConfig.log('toggleFollow: ${result['message']}');
          // 如果是"已经关注对方"的错误，仍然添加到本地列表
          if (result['message']?.toString().contains('已经关注') != true) {
            return false;
          }
        }
        // 添加到本地列表
        _following.add(Friend(
          id: targetUid,
          name: '用户$targetUid',
          avatarUrl: '',
        ));
      }
      notifyListeners();
      return true;
    } catch (e) {
      AppConfig.log('toggleFollow error: $e');
      return false;
    }
  }

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

  /// 根据用户ID获取用户信息（优先从缓存，其次从好友列表，最后从API获取）
  Friend? getUserById(String id) {
    // 优先从缓存中查找
    if (_userCache.containsKey(id)) {
      return _userCache[id];
    }

    // 其次从好友列表中查找
    final friend = friendById(id);
    if (friend != null) {
      _userCache[id] = friend; // 缓存起来
      return friend;
    }

    return null;
  }

  /// 异步获取用户信息（如果缓存中没有，则从API获取）
  Future<Friend?> fetchUserById(String id) async {
    // 已在缓存中
    if (_userCache.containsKey(id)) {
      return _userCache[id];
    }

    // 从好友列表中查找
    final friend = friendById(id);
    if (friend != null) {
      _userCache[id] = friend;
      return friend;
    }

    // 正在获取中，不重复请求
    if (_fetchingUserIds.contains(id)) {
      return null;
    }

    // 从API获取
    if (relationRepository == null) return null;

    final userId = int.tryParse(id);
    if (userId == null) return null;

    _fetchingUserIds.add(id);

    try {
      final users = await relationRepository!.getUsersByIds([userId]);
      if (users.isNotEmpty) {
        _userCache[id] = users.first;
        notifyListeners();
        return users.first;
      }
    } catch (e) {
      AppConfig.log('[MessagingProvider] 获取用户 $id 信息失败: $e');
    } finally {
      _fetchingUserIds.remove(id);
    }

    return null;
  }

  /// 检查用户信息是否已缓存
  bool hasUserCache(String id) {
    return _userCache.containsKey(id) || friendById(id) != null;
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
    _userCache.clear();
    _fetchingUserIds.clear();
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
      AppConfig.log('[MessagingProvider] onMessage收到数据: ${rawData.runtimeType}');

      Map<String, dynamic>? data;

      // 尝试将rawData转换为Map
      if (rawData is Map) {
        data = Map<String, dynamic>.from(rawData);
        AppConfig.log('[MessagingProvider] rawData是Map类型');
      } else if (rawData is String) {
        final trimmed = rawData.trim();
        AppConfig.log('[MessagingProvider] rawData是String: ${trimmed.substring(0, trimmed.length > 200 ? 200 : trimmed.length)}');
        // 处理Go map格式的字符串（支持换行符）
        if (trimmed.startsWith('map[')) {
          data = parseGoMapString(trimmed);
          AppConfig.log('[MessagingProvider] 解析Go map结果: $data');
        }
      }

      if (data == null) {
        AppConfig.log('[MessagingProvider] data为null，跳过处理');
        return;
      }

      final type = data['type'];
      AppConfig.log('[MessagingProvider] 消息类型: $type');

      if (type == 'history') {
        final messages = data['messages'];
        AppConfig.log('[MessagingProvider] 收到history消息，messages类型: ${messages.runtimeType}, 长度: ${messages is List ? messages.length : "N/A"}');
        _handleHistoryMessage(messages);
      } else if (data.containsKey('content') && data.containsKey('from')) {
        _handleSingleMessage(data);
      }
    };
  }

  void _handleHistoryMessage(dynamic rawMessages) {
    final uid = currentUid;
    if (rawMessages == null || uid == null) {
      AppConfig.log('[_handleHistoryMessage] rawMessages或uid为null');
      return;
    }

    // 确保rawMessages是List类型
    List<dynamic> messageList;
    if (rawMessages is List) {
      messageList = rawMessages;
    } else {
      AppConfig.log('[_handleHistoryMessage] rawMessages不是List: ${rawMessages.runtimeType}');
      return;
    }

    AppConfig.log('[_handleHistoryMessage] 开始处理 ${messageList.length} 条消息');

    final Map<String, List<ChatMessage>> serverMsgMap = {};

    for (int i = 0; i < messageList.length; i++) {
      final item = messageList[i];
      try {
        // 调试日志：打印每条消息的原始数据
        AppConfig.log('[_handleHistoryMessage] 消息[$i] 类型: ${item.runtimeType}');

        ChatMessage? msg;

        // 使用tryParse自动检测并解析各种格式
        msg = ChatMessage.tryParse(item);

        if (msg != null) {
          AppConfig.log('[_handleHistoryMessage] 消息[$i] tryParse成功');
        } else {
          AppConfig.log('[_handleHistoryMessage] 消息[$i] tryParse返回null');
        }

        // 如果tryParse失败，尝试直接解析
        if (msg == null && item is Map) {
          msg = ChatMessage.fromJson(Map<String, dynamic>.from(item));
          AppConfig.log('[_handleHistoryMessage] 消息[$i] fromJson成功');
        }

        if (msg == null) {
          AppConfig.log('[_handleHistoryMessage] 消息[$i] 解析失败，跳过');
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
        AppConfig.log('[_handleHistoryMessage] 消息[$i] 解析异常: $e');
      }
    }

    AppConfig.log('[_handleHistoryMessage] 解析完成，共 ${serverMsgMap.length} 个会话');
    AppConfig.log('[$_logTag] ========== 开始合并历史消息 ==========');

    // 使用新的去重方法合并消息
    serverMsgMap.forEach((key, serverMsgs) {
      final localMsgs = _messages[key] ?? [];
      AppConfig.log('[$_logTag] 会话[$key]: 服务器消息=${serverMsgs.length}, 本地消息=${localMsgs.length}');

      // 使用统一的合并去重方法
      _messages[key] = _mergeAndDedup(serverMsgs, localMsgs);
    });

    // 处理本地有但服务器没有返回的会话（保留本地消息并排序）
    for (var key in _messages.keys.toList()) {
      if (!serverMsgMap.containsKey(key)) {
        final localMsgs = _messages[key]!;
        AppConfig.log('[$_logTag] 会话[$key]: 服务器无数据，保留本地消息=${localMsgs.length}');
        localMsgs.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      }
    }

    AppConfig.log('[$_logTag] ========== 合并历史消息完成 ==========');

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
      AppConfig.log('[$_logTag] 收到单条消息: id=${msg.id}, sig=$newMsgSig');

      // 查找是否有匹配的临时消息（负数ID）或重复消息
      final existingIndex = list.indexWhere((m) {
        // 精确ID匹配（仅当两者都是服务器消息时）
        if (m.id > 0 && msg.id > 0 && m.id == msg.id) return true;
        // 内容签名匹配（用于临时消息替换和去重）
        return _contentSignature(m) == newMsgSig;
      });

      if (existingIndex >= 0) {
        final existing = list[existingIndex];
        AppConfig.log('[$_logTag] 找到匹配消息: existingId=${existing.id}, newId=${msg.id}');

        // 如果已存在的是临时消息（负数ID），用服务器消息替换
        if (existing.id < 0 && msg.id > 0) {
          AppConfig.log('[$_logTag] 替换临时消息为服务器消息');
          list[existingIndex] = msg;
          list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          notifyListeners();
          _saveHistoryToHive();
        } else {
          AppConfig.log('[$_logTag] 跳过重复消息');
        }
        // 否则是重复消息，忽略
      } else {
        // 新消息，添加并排序
        AppConfig.log('[$_logTag] 添加新消息到列表');
        list.add(msg);
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        notifyListeners();
        _saveHistoryToHive();
      }
    } catch (e) {
      AppConfig.log('[$_logTag] 处理单条消息异常: $e');
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
