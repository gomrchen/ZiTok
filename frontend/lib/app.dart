import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitok/providers/comment_provider.dart';
import 'package:zitok/providers/user_provider.dart';
import 'package:zitok/repositories/comment_repository.dart';
import 'package:zitok/repositories/user_repository.dart';
import 'package:zitok/services/comment_service.dart';
import 'package:zitok/services/user_service.dart';

import 'config/env.dart';
import 'routes/app_router.dart';
import 'providers/theme_provider.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'repositories/auth_repository.dart';
import 'providers/auth_provider.dart';
import 'repositories/video_repository.dart';
import 'services/video_service.dart';
import 'services/cache.dart';
import 'providers/video_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/messaging_provider.dart';

class AppBootstrap {
  static late SharedPreferences prefs;
  static late ApiClient apiClient;

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox('user_box');
    await Hive.openBox('feed_cache_box');
    await Hive.openBox('notes_box');
    await Hive.openBox('messages_box');

    prefs = await SharedPreferences.getInstance();
    prefs.setString('access_token', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjI3ODY3NzYsInVzZXJfaWQiOjF9.YP1QCgnSLmQ34ZMpx9BNIdzSrW0dLYy4U0tNrpJpIvc');
    apiClient = ApiClient(baseUrl: Env.baseUrl, prefs: prefs);
  }
}

class ZitokApp extends StatelessWidget {
  const ZitokApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authRepository = AuthRepository(
      authService: AuthService(AppBootstrap.apiClient),
      prefs: AppBootstrap.prefs,
    );
    final videoRepository = VideoRepository(
      api: VideoService(AppBootstrap.apiClient.dio),
      cache: CacheManager(AppBootstrap.prefs),
    );
    final commentRepository = CommentRepository(
      api: CommentService(AppBootstrap.apiClient.dio),
      userProvider: UserProvider(repo: UserRepository(api: UserService(AppBootstrap.apiClient.dio))),
    );
    final userRepository = UserRepository(
      api: UserService(AppBootstrap.apiClient.dio),
    );
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(authRepository: authRepository),
        ),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(prefs: AppBootstrap.prefs),
        ),
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider(prefs: AppBootstrap.prefs),
        ),
        ChangeNotifierProvider<VideoProvider>(
          create: (_) => VideoProvider(repo: videoRepository)
            ..refreshDiscover()
            ..refreshFeatured(),
        ),
        ChangeNotifierProvider<MessagingProvider>(
          create: (_) => MessagingProvider(),
        ),
        ChangeNotifierProvider<CommentProvider>(
          create: (_) => CommentProvider(repo: commentRepository),
        ),
        ChangeNotifierProvider(
          create: (context) => UserProvider( repo: userRepository),
        ),
      ],
      child: Builder(
        builder: (context) {
          final router = AppRouter.buildRouter(context.read<AuthProvider>());
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
