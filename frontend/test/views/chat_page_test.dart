import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zitok/providers/messaging_provider.dart';

import 'package:zitok/views/chat/chat_page.dart';

void main() {
  testWidgets('ChatPage sends and displays message', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => MessagingProvider())],
        child: const MaterialApp(home: ChatPage(conversationId: 'u7')),
      ),
    );

    // 输入并发送消息
    final textField = find.byType(TextField).first;
    await tester.enterText(textField, '你好');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('你好'), findsOneWidget);
  });
}