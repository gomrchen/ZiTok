// test/create/create_page_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:zitok/views/create/create_page.dart';
import 'package:zitok/providers/video_provider.dart';
import 'package:zitok/services/user_session.dart';
import 'package:zitok/repositories/video_repository.dart';
import 'package:zitok/services/video_service.dart';
import 'package:zitok/services/api_client.dart';
import 'package:zitok/services/cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 使用 dynamic 类型，因为 _CreatePageState 是私有的
dynamic getPageState(GlobalKey key) {
  return key.currentState;
}

void main() {
  late VideoRepository mockRepo;
  late SharedPreferences prefs;

  setUp(() async {
    // 初始化 SharedPreferences mock
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    // 重置 UserSession 单例以便测试
    UserSession.resetInstance();

    // 创建模拟仓库
    final apiClient = ApiClient(baseUrl: 'http://mock', prefs: prefs);
    mockRepo = VideoRepository(
      api: VideoService(apiClient.dio),
      cache: CacheManager(prefs),
    );
  });

  // 辅助函数，用于构建被测试的Widget（使用更大的测试屏幕）
  Widget createTestScreen(Key key, VideoRepository repo) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<VideoProvider>(
          create: (_) => VideoProvider(repo: repo),
        ),
        ChangeNotifierProvider<UserSession>.value(value: UserSession.instance),
      ],
      child: MaterialApp(
        home: CreatePage(key: key),
      ),
    );
  }

  group('CreatePage - UI结构测试', () {
    testWidgets('测试点1: 初始显示素材准备阶段', (WidgetTester tester) async {
      final pageKey = GlobalKey<State<CreatePage>>();
      await tester.pumpWidget(createTestScreen(pageKey, mockRepo));

      // 验证初始状态显示素材准备阶段
      expect(find.text('从本地导入视频'), findsOneWidget);
    });

    testWidgets('测试点2: 可以通过StepIndicator导航', (WidgetTester tester) async {
      final pageKey = GlobalKey<State<CreatePage>>();
      await tester.pumpWidget(createTestScreen(pageKey, mockRepo));

      // 点击"内容编辑"步骤
      await tester.tap(find.text('内容编辑'));
      await tester.pumpAndSettle();

      // 验证进入内容编辑阶段
      expect(find.text('视频标题 *'), findsOneWidget);
    });

    testWidgets('测试点3: 内容编辑阶段有正确的表单字段', (WidgetTester tester) async {
      final pageKey = GlobalKey<State<CreatePage>>();
      await tester.pumpWidget(createTestScreen(pageKey, mockRepo));

      // 直接导航到内容编辑阶段
      await tester.tap(find.text('内容编辑'));
      await tester.pumpAndSettle();

      // 验证表单字段存在
      expect(find.text('视频标题 *'), findsOneWidget);
      expect(find.text('作品简介'), findsOneWidget);
      expect(find.text('视频标签'), findsOneWidget);
      expect(find.text('已准备的素材'), findsOneWidget);
    });

    testWidgets('测试点4: 发布阶段有确认发布按钮', (WidgetTester tester) async {
      final pageKey = GlobalKey<State<CreatePage>>();
      await tester.pumpWidget(createTestScreen(pageKey, mockRepo));

      // 直接导航到发布阶段
      await tester.tap(find.text('发布'));
      await tester.pumpAndSettle();

      // 验证发布阶段元素存在
      expect(find.text('发布信息'), findsOneWidget);
      expect(find.text('视频预览'), findsOneWidget);
      expect(find.text('Markdown 预览'), findsOneWidget);
    });

    testWidgets('测试点5: CreatePage能正确渲染', (WidgetTester tester) async {
      final pageKey = GlobalKey<State<CreatePage>>();
      await tester.pumpWidget(createTestScreen(pageKey, mockRepo));

      // 验证CreatePage渲染成功
      expect(find.byType(CreatePage), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('CreatePage - 状态管理测试', () {
    testWidgets('测试: 可以通过state设置视频源', (WidgetTester tester) async {
      final pageKey = GlobalKey<State<CreatePage>>();
      await tester.pumpWidget(createTestScreen(pageKey, mockRepo));

      // 设置视频源
      final state = getPageState(pageKey);
      state.videoSource = 'http://example.com/video.mp4';
      state.videoName = 'video.mp4';
      await tester.pump();

      // 导航到内容编辑阶段验证
      await tester.tap(find.text('内容编辑'));
      await tester.pumpAndSettle();

      // 验证视频名称显示
      expect(find.textContaining('video.mp4'), findsWidgets);
    });
  });
}
