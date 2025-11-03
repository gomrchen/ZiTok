// test/views/create/create_page_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 确保路径正确
import 'package:zitok/views/create/create_page.dart';

// 我们使用 dynamic 类型，因为 _CreatePageState 是私有的
dynamic getPageState(GlobalKey key) {
  return key.currentState;
}

void main() {
  // 辅助函数，用于构建被测试的Widget
  Widget createTestScreen(Key key) {
    return MaterialApp(
      home: CreatePage(key: key),
    );
  }

  group('CreatePage - 完整发布流程测试', () {
    testWidgets('测试点1: 提供视频URL和Markdown内容，应发布成功', (WidgetTester tester) async {
      // --- Arrange (设置) ---
      final pageKey = GlobalKey<State<CreatePage>>();
      await tester.pumpWidget(createTestScreen(pageKey));

      const validVideoUrl = 'http://vjs.zencdn.net/v/oceans.mp4';
      const markdownContent = '# 测试标题\n\n这是 **Markdown** 内容。';

      // --- Act (操作) ---
      final state = getPageState(pageKey);
      state.videoSource = validVideoUrl;
      state.videoName = 'oceans.mp4';
      state.mdContent = markdownContent;
      await tester.pump();

      await tester.tap(find.text('内容编辑'));
      await tester.pumpAndSettle();

      final publishButtonFinder = find.ancestor(
        of: find.text('发布'),
        matching: find.byType(FilledButton),
      );
      await tester.ensureVisible(publishButtonFinder);
      await tester.pumpAndSettle();

      await tester.tap(publishButtonFinder);
      await tester.pumpAndSettle();

      // --- Assert (断言) ---
      expect(find.text('发布成功（本地模拟）'), findsOneWidget, reason: '合法输入时应提示发布成功');
      expect(find.textContaining('发布失败'), findsNothing, reason: '成功时不应提示失败');
    });

    testWidgets('测试点2: 未提供视频和Markdown，点击发布应失败', (WidgetTester tester) async {
      await tester.pumpWidget(createTestScreen(GlobalKey()));

      await tester.tap(find.text('内容编辑'));
      await tester.pumpAndSettle();

      final publishButtonFinder = find.ancestor(
        of: find.text('发布'),
        matching: find.byType(FilledButton),
      );
      await tester.ensureVisible(publishButtonFinder);
      await tester.pumpAndSettle();
      await tester.tap(publishButtonFinder);
      await tester.pumpAndSettle();

      expect(find.text('发布失败：视频、笔记与描述不能全部为空'), findsOneWidget, reason: '所有内容为空时，应提示失败');
    });

    testWidgets('测试点3: 提供不支持的视频格式，点击发布应失败', (WidgetTester tester) async {
      // --- Arrange ---
      final pageKey = GlobalKey<State<CreatePage>>();
      await tester.pumpWidget(createTestScreen(pageKey));
      final state = getPageState(pageKey);

      // 【最终修复】: 使用一个真正不支持的视频格式，比如 .flv
      state.videoSource = 'http://example.com/video.flv';
      state.videoName = 'video.flv';
      state.mdContent = '一些有效内容';
      await tester.pump();

      // --- Act ---
      await tester.tap(find.text('内容编辑'));
      await tester.pumpAndSettle();

      final publishButtonFinder = find.ancestor(
        of: find.text('发布'),
        matching: find.byType(FilledButton),
      );
      await tester.ensureVisible(publishButtonFinder);
      await tester.pumpAndSettle();
      await tester.tap(publishButtonFinder);
      await tester.pumpAndSettle();

      // --- Assert ---
      // 现在，断言应该能够成功找到这个错误提示了
      expect(find.text('不支持的视频格式（仅支持 mp4/mov/avi/mkv）'), findsOneWidget, reason: '视频格式不支持时应提示错误');
    });
  });
}
