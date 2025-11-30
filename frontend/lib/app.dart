import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/env.dart';
import 'routes/app_router.dart';
import 'providers/theme_provider.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/user_session.dart';
import 'repositories/auth_repository.dart';
import 'providers/auth_provider.dart';
import 'repositories/video_repository.dart';
import 'services/video_service.dart';
import 'services/cache.dart';
import 'providers/video_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/messaging_provider.dart';
import 'repositories/user_repository.dart';
import 'services/user_service.dart';
import 'providers/profile_provider.dart';
import 'providers/user_provider.dart';
import 'repositories/comment_repository.dart';
import 'services/comment_service.dart';
import 'providers/comment_provider.dart';
import 'repositories/relation_repository.dart';
import 'services/relation_service.dart';

class AppBootstrap {
  static late SharedPreferences prefs;
  static late ApiClient apiClient;
  static late UserSession userSession;

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox('user_box');
    await Hive.openBox('feed_cache_box');
    await Hive.openBox('notes_box');
    await Hive.openBox('messages_box');

    prefs = await SharedPreferences.getInstance();
    apiClient = ApiClient(baseUrl: Env.baseUrl, prefs: prefs);

    // 初始化用户会话（唯一真实来源）
    userSession = UserSession.instance;
    await userSession.restoreSession(prefs);

    // 迁移旧的 auth_user_id 到新的 user_id
    await _migrateUserId();

    // 验证本地缓存的token和用户状态
    await _validateSession();
  }

  /// 迁移旧的用户 ID 存储方式
  static Future<void> _migrateUserId() async {
    final oldUserId = prefs.getString('auth_user_id');
    final newUserId = prefs.getString('user_id');

    // 如果旧的存在但新的不存在，迁移
    if (oldUserId != null && oldUserId.isNotEmpty && newUserId == null) {
      await prefs.setString('user_id', oldUserId);
      await userSession.restoreSession(prefs);
    }
  }

  /// 验证本地缓存的会话是否仍然有效
  ///
  /// 如果本地有token和userId，向服务端验证用户是否仍然存在。
  /// 验证失败时清除本地缓存，确保用户需要重新登录。
  static Future<void> _validateSession() async {
    // 如果没有登录信息或没有有效token，无需验证
    if (!userSession.isLoggedIn || !userSession.hasValidToken) {
      if (userSession.userId != null && !userSession.hasValidToken) {
        // 有userId但没有token，清除会话
        await _clearSession();
      }
      return;
    }

    try {
      // 调用 /user/info 验证token和用户状态
      final response = await apiClient.dio.get('/user/info');
      final body = response.data as Map<String, dynamic>? ?? {};
      final code = body['code'];

      // 检查业务码
      if (code != 10000 && code != 200 && !(code == 0 && response.statusCode == 200)) {
        // 业务码异常，可能用户被删除
        await _clearSession();
        return;
      }

      // 检查返回的用户数据
      final data = body['data'] as Map<String, dynamic>?;
      if (data == null) {
        await _clearSession();
        return;
      }

      // 检查用户是否被删除（如果后端返回deleted_at字段）
      final deletedAt = data['deleted_at'];
      if (deletedAt != null && deletedAt.toString().isNotEmpty) {
        await _clearSession();
        return;
      }

      // 验证通过，可以选择更新本地用户信息
    } catch (e) {
      // 网络错误或服务端错误
      // 对于 401/403 错误，清除会话
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        if (statusCode == 401 || statusCode == 403) {
          await _clearSession();
          return;
        }
        // 其他网络错误（如无网络），保留本地会话，让用户可以查看缓存内容
      }
    }
  }

  /// 清除本地会话信息
  static Future<void> _clearSession() async {
    await userSession.clear(prefs);
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('auth_user_id');
  }
}

class ZitokApp extends StatelessWidget {
  const ZitokApp({super.key});

  static GoRouter? _routerCache;

  @override
  Widget build(BuildContext context) {
    final authRepository = AuthRepository(
      authService:
          AuthService(AppBootstrap.apiClient, prefs: AppBootstrap.prefs),
      prefs: AppBootstrap.prefs,
      userSession: AppBootstrap.userSession,
    );
    final videoRepository = VideoRepository(
      api: VideoService(AppBootstrap.apiClient.dio),
      cache: CacheManager(AppBootstrap.prefs),
      getUserId: () => AppBootstrap.userSession.userId,
    );
    final userRepository =
        UserRepository(api: UserService(AppBootstrap.apiClient.dio));
    final relationService = RelationService(AppBootstrap.apiClient.dio);
    final relationRepository = RelationRepository(api: relationService);

    return MultiProvider(
      providers: [
        // UserSession 作为全局可访问的服务
        ChangeNotifierProvider<UserSession>.value(
          value: AppBootstrap.userSession,
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(
            authRepository: authRepository,
            userSession: AppBootstrap.userSession,
          ),
        ),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(prefs: AppBootstrap.prefs),
        ),
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider(prefs: AppBootstrap.prefs),
        ),
        ChangeNotifierProvider<VideoProvider>(
          create: (_) => VideoProvider(
            repo: videoRepository,
            userSession: AppBootstrap.userSession,
          ),
        ),
        ChangeNotifierProvider<MessagingProvider>(
          create: (_) => MessagingProvider(
            relationRepository: relationRepository,
            userSession: AppBootstrap.userSession,
          ),
        ),
        ChangeNotifierProvider<ProfileProvider>(
          create: (_) => ProfileProvider(
            repo: userRepository,
            userSession: AppBootstrap.userSession,
          ),
        ),
        ChangeNotifierProvider<UserProvider>(
          create: (_) => UserProvider(repo: userRepository),
        ),
        ChangeNotifierProvider<CommentProvider>(
          create: (context) => CommentProvider(
            repo: CommentRepository(
              api: CommentService(AppBootstrap.apiClient.dio),
              userProvider: context.read<UserProvider>(),
            ),
          ),
        ),
      ],
      child: Builder(
        builder: (context) {
          final authProvider = context.read<AuthProvider>();
          final router = _routerCache ??= AppRouter.buildRouter(authProvider);
          final theme = context.watch<ThemeProvider>().theme;

          return MaterialApp.router(
            title: '知音App',
            theme: theme,
            routerConfig: router,
          );
        },
      ),
    );
  }
}
