import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zitok/widgets/comment_sheet.dart';
<<<<<<< HEAD

=======
//ztc作业1
>>>>>>> aaa4da01b9747b50aad04275356db124e0cdca7d
void main() {
  testWidgets('Comment sheet shows tabs and collapsible replies', (tester) async {
    final app = MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(
              onPressed: () => showCommentsSheet(ctx, videoId: 'vid123'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(app);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Tabs exist
    expect(find.text('视频简介'), findsOneWidget);
    expect(find.text('评论区'), findsOneWidget);

    // 切换到评论区
    await tester.tap(find.text('评论区'));
    await tester.pumpAndSettle();

    // 基本内容可见
    expect(find.textContaining('评论（'), findsOneWidget);

    // 评论列表渲染正常（存在父评论头像）
    expect(find.byType(CircleAvatar), findsWidgets);

    // Bottom input hint exists
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('写下你的评论...'), findsOneWidget);

    // Like button tap increases count visually
    final likeBtn = find.byIcon(Icons.favorite_border).first;
    await tester.tap(likeBtn);
    await tester.pump();
    expect(find.byIcon(Icons.favorite), findsWidgets);
  });
<<<<<<< HEAD
}
=======
}
>>>>>>> aaa4da01b9747b50aad04275356db124e0cdca7d
