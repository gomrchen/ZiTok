import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/env.dart';
import 'l10n/app_localizations.dart';
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
import 'services/drama_service.dart';
import 'providers/drama_provider.dart';

class AppBootstrap {
  static late SharedPreferences prefs;
  static late ApiClient apiClient;
  static late UserSession userSession;

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox('user_box');
    await Hive.openBox('feed_cache_box');
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
  /// 新逻辑：
  /// 1. 如果有 userId 和 refreshToken，尝试刷新token
  /// 2. 刷新成功：更新token，允许进入应用
  /// 3. 刷新失败：清除会话，需要重新登录
  /// 4. 网络错误：保留会话，允许查看缓存内容
  static Future<void> _validateSession() async {
    // 如果没有自动登录所需的凭据，无需验证
    if (!userSession.canAttemptAutoLogin) {
      // 清理可能存在的不完整会话数据
      if (userSession.userId != null || userSession.refreshToken != null) {
        await _clearSession();
      }
      return;
    }

    // 如果已有有效token，先尝试验证
    if (userSession.hasValidToken) {
      try {
        final response = await apiClient.dio.get('/user/info');
        final body = response.data as Map<String, dynamic>? ?? {};
        final code = body['code'];

        // 验证成功
        if (code == 10000 || code == 200 || (code == '10000')) {
          return;
        }
      } catch (e) {
        if (e is DioException) {
          final statusCode = e.response?.statusCode;
          // 401/403 表示token无效，继续尝试刷新
          if (statusCode != 401 && statusCode != 403) {
            // 其他网络错误，保留会话
            return;
          }
        }
      }
    }

    // 尝试刷新token
    await _tryRefreshToken();
  }

  /// 尝试刷新token
  ///
  /// 返回 true 表示刷新成功，false 表示失败
  static Future<bool> _tryRefreshToken() async {
    final userId = userSession.userId;
    final refreshToken = userSession.refreshToken;

    if (userId == null || refreshToken == null) {
      return false;
    }

    try {
      final authService = AuthService(apiClient, prefs: prefs);
      final response = await authService.refreshToken(
        userId: userId,
        refreshToken: refreshToken,
      );

      final body = response.data as Map<String, dynamic>? ?? {};
      final code = body['code']?.toString();

      // 检查响应码
      if (code != '10000' && code != '200') {
        await _clearSession();
        return false;
      }

      // 解析token
      final data = body['data'] as Map<String, dynamic>? ?? body;
      final newToken = (data['token'] ?? data['access_token'])?.toString();
      final newRefreshToken = (data['refresh_token'] ?? data['refreshToken'])?.toString();

      if (newToken == null || newToken.isEmpty) {
        await _clearSession();
        return false;
      }

      // 更新token
      await userSession.setTokens(
        prefs,
        accessToken: newToken,
        refreshToken: newRefreshToken,
      );

      return true;
    } catch (e) {
      // 网络错误：保留会话（允许查看缓存内容）
      // 认证错误：清除会话
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        if (statusCode == 401 || statusCode == 403 || statusCode == 400) {
          await _clearSession();
          return false;
        }
        // 网络不可用等错误，保留会话
        return false;
      }
      await _clearSession();
      return false;
    }
  }

  /// 公开方法：在应用运行时刷新token
  ///
  /// 用于主界面进入后在后台刷新token
  /// 返回 true 表示刷新成功或无需刷新，false 表示认证失效
  static Future<bool> refreshTokenIfNeeded() async {
    if (!userSession.canAttemptAutoLogin) {
      return false;
    }

    // 如果已有有效token，先验证是否仍然有效
    if (userSession.hasValidToken) {
      try {
        final response = await apiClient.dio.get('/user/info');
        final body = response.data as Map<String, dynamic>? ?? {};
        final code = body['code']?.toString();
        if (code == '10000' || code == '200') {
          return true; // token仍然有效
        }
      } catch (e) {
        if (e is DioException) {
          final statusCode = e.response?.statusCode;
          if (statusCode != 401 && statusCode != 403) {
            return true; // 网络错误，假设token有效
          }
        }
      }
    }

    // 尝试刷新token
    final success = await _tryRefreshToken();
    if (!success && userSession.onAuthenticationFailed != null) {
      // 触发认证失效回调
      userSession.onAuthenticationFailed!();
    }
    return success;
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
        ChangeNotifierProvider<DramaProvider>(
          create: (_) => DramaProvider(
            dramaService: DramaService(AppBootstrap.apiClient.dio),
            commerceService: CommerceService(AppBootstrap.apiClient.dio),
          ),
        ),
      ],
      child: Builder(
        builder: (context) {
          final authProvider = context.read<AuthProvider>();
          final router = _routerCache ??= AppRouter.buildRouter(authProvider);
          final theme = context.watch<ThemeProvider>().theme;
          final locale = context.watch<SettingsProvider>().locale;

          return MaterialApp.router(
            onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,
            theme: theme,
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            routerConfig: router,
          );
        },
      ),
    );
  }
}
