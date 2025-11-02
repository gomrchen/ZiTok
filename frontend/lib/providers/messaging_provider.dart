import 'package:flutter/foundation.dart';

class Friend {
  final String id;
  final String name;
  final String avatarUrl;
  final bool online;
  const Friend({required this.id, required this.name, required this.avatarUrl, this.online = false});
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId; // 'me' 或好友 id
  final String text;
  final DateTime timestamp;
  const ChatMessage({required this.id, required this.conversationId, required this.senderId, required this.text, required this.timestamp});
}

class MessagingProvider extends ChangeNotifier {
  final Map<String, List<ChatMessage>> _messages = {};
  final List<Friend> _friends = const [
    Friend(id: 'u1', name: '无烟校园', avatarUrl: 'https://i.pravatar.cc/100?img=1', online: true),
    Friend(id: 'u2', name: '金jin', avatarUrl: 'https://i.pravatar.cc/100?img=2', online: true),
    Friend(id: 'u3', name: '小小耶耶', avatarUrl: 'https://i.pravatar.cc/100?img=3'),
    Friend(id: 'u4', name: '上十', avatarUrl: 'https://i.pravatar.cc/100?img=4'),
    Friend(id: 'u5', name: 'serena', avatarUrl: 'https://i.pravatar.cc/100?img=5'),
    Friend(id: 'u6', name: 'copy', avatarUrl: 'https://i.pravatar.cc/100?img=6'),
    Friend(id: 'u7', name: 'j1at', avatarUrl: 'https://i.pravatar.cc/100?img=7'),
  ];

  List<Friend> get friends => List.unmodifiable(_friends);

  Friend? friendById(String id) => _friends.cast<Friend?>().firstWhere((f) => f!.id == id, orElse: () => null);

  List<ChatMessage> messagesFor(String conversationId) {
    return List.unmodifiable(_messages[conversationId] ?? const []);
  }

  void sendMessage(String conversationId, String text) {
    final msg = ChatMessage(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      conversationId: conversationId,
      senderId: 'me',
      text: text,
      timestamp: DateTime.now(),
    );
    final list = _messages.putIfAbsent(conversationId, () => []);
    list.add(msg);
    notifyListeners();
  }

  void receiveMessage(String conversationId, String text, {String from = 'peer'}) {
    final msg = ChatMessage(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      conversationId: conversationId,
      senderId: from,
      text: text,
      timestamp: DateTime.now(),
    );
    final list = _messages.putIfAbsent(conversationId, () => []);
    list.add(msg);
    notifyListeners();
  }

  List<Friend> searchFriends(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return friends;
    return friends.where((f) => f.name.toLowerCase().contains(q)).toList(growable: false);
  }
}