import 'package:flutter_test/flutter_test.dart';
import 'package:zitok/models/social_models.dart';

/// 对齐 FriendSearchPage / MessagingProvider.searchConversations 的匹配规则
List<Conversation> filterConversations(List<Conversation> all, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return all;
  return all.where((c) {
    final name = c.name.toLowerCase();
    final id = c.id;
    return name.contains(q) || id.contains(q);
  }).toList();
}

void main() {
  late List<Conversation> data;

  setUp(() {
    data = [
      Friend.fromMergedData({'id': 2, 'username': 'zitok_peer'}, 1),
      ChatRoom.fromJson({'id': 1, 'name': 'ZiTok联调群', 'creator_id': 1, 'type': 2}),
      ChatRoom.fromJson({'id': 2, 'name': '短剧讨论组', 'creator_id': 1, 'type': 2}),
    ];
  });

  test('搜「联调」命中群聊', () {
    final r = filterConversations(data, '联调');
    expect(r.length, 1);
    expect(r.first.name, 'ZiTok联调群');
    expect(r.first.isGroup, isTrue);
  });

  test('搜「ZiTok」同时命中好友与群', () {
    final r = filterConversations(data, 'ZiTok');
    expect(r.map((e) => e.name), containsAll(['zitok_peer', 'ZiTok联调群']));
  });

  test('搜「短剧」只命中讨论组', () {
    final r = filterConversations(data, '短剧');
    expect(r.single.name, '短剧讨论组');
  });

  test('按群 ID 搜索', () {
    final r = filterConversations(data, '1');
    expect(r.single.name, 'ZiTok联调群');
  });

  test('无匹配返回空', () {
    expect(filterConversations(data, 'xyz'), isEmpty);
  });
}
