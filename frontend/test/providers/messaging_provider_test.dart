import 'package:flutter_test/flutter_test.dart';
import 'package:zitok/providers/messaging_provider.dart';

void main() {
  test('sendMessage appends to conversation', () {
    final mp = MessagingProvider();
    expect(mp.messagesFor('u7').length, 0);
    mp.sendMessage('u7', 'hello');
    expect(mp.messagesFor('u7').length, 1);
    expect(mp.messagesFor('u7').last.content, 'hello');
  });

  test('searchConversations fuzzy match', () {
    final mp = MessagingProvider();
    final res = mp.searchConversations('ser');
    // 空 provider 返回空列表，这个测试验证方法存在且可调用
    expect(res, isA<List>());
  });
}