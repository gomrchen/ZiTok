import 'package:flutter_test/flutter_test.dart';
import 'package:zitok/providers/messaging_provider.dart';

void main() {
  test('sendMessage appends to conversation', () {
    final mp = MessagingProvider();
    expect(mp.messagesFor('u7').length, 0);
    mp.sendMessage('u7', 'hello');
    expect(mp.messagesFor('u7').length, 1);
    expect(mp.messagesFor('u7').last.text, 'hello');
  });

  test('searchFriends fuzzy match', () {
    final mp = MessagingProvider();
    final res = mp.searchFriends('ser');
    expect(res.any((f) => f.name.toLowerCase().contains('ser')), true);
  });
}