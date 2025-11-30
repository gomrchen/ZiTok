import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../views/welcome/welcome_page.dart';
import '../views/auth/login_page.dart';
import '../views/auth/register_page.dart';
import '../views/auth/forgot_password_page.dart';
import '../views/home/home_shell.dart';
import '../views/video/video_detail_page.dart';
import '../views/notes/video_notes_page.dart';
import '../views/notes/note_detail_page.dart';
import '../views/messages/messages_page.dart';
import '../views/chat/chat_page.dart';
import '../views/profile/edit_profile_page.dart';
import '../views/settings/settings_page.dart';
import '../views/profile/video_manage_page.dart';
import '../views/profile/note_manage_page.dart';
import '../views/search/search_page.dart';
import '../views/search/search_results_page.dart';
import '../views/video/video_list_page.dart';
import '../views/settings/change_password_page.dart';
import '../views/settings/account_switcher_page.dart';
import '../views/settings/account_settings_page.dart';
import '../views/profile/visitor_profile_page.dart';

class AppRouter {
  static GoRouter buildRouter(AuthProvider auth) {
    return GoRouter(
      initialLocation: '/welcome',
      refreshListenable: null,
      routes: [
        GoRoute(
          path: '/welcome',
          builder: _builder((_) => const WelcomePage()),
        ),
        GoRoute(
          path: '/auth/login',
          builder: _builder((_) => const LoginPage()),
        ),
        GoRoute(
          path: '/auth/register',
          builder: _builder((_) => const RegisterPage()),
        ),
        GoRoute(
          path: '/auth/forgot-password',
          builder: _builder((_) => const ForgotPasswordPage()),
        ),
        // 统一主界面（组件化四模块）
        GoRoute(path: '/home', builder: _builder((_) => const HomeShell())),
        // 消息列表与聊天
        GoRoute(
          path: '/messages',
          builder: _builder((_) => const MessagesPage()),
        ),
        GoRoute(
          path: '/chat/:cid',
          builder: _builder(
            (state) => ChatPage(conversationId: state.pathParameters['cid']!),
          ),         
        ),

        // 非主界面详情页与设置
        GoRoute(
          path: '/video/:id',
          builder: _builder(
            (state) => VideoDetailPage(id: state.pathParameters['id']!),
          ),
        ),
        GoRoute(
          path: '/video/:id/notes',
          builder: _builder(
            (state) => VideoNotesPage(videoId: state.pathParameters['id']!),
          ),
        ),
        GoRoute(
          path: '/note/:id',
          builder: _builder(
            (state) => NoteDetailPage(id: state.pathParameters['id']!),
          ),
        ),
        // 注意：这里导入的NoteDetailPage来自notes包，不是profile包
        GoRoute(
          path: '/profile/video/:id/manage',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: VideoManagePage.fromState(state),
            transitionsBuilder: (ctx, a, __, child) =>
                FadeTransition(opacity: a, child: child),
          ),
        ),
        GoRoute(
          path: '/profile/note/:id/manage',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: NoteManagePage.fromState(state),
            transitionsBuilder: (ctx, a, __, child) =>
                FadeTransition(opacity: a, child: child),
          ),
        ),
        GoRoute(
          path: '/profile/edit',
          builder: _builder((_) => const EditProfilePage()),
        ),
        // 访客个人主页
        GoRoute(
          path: '/user/:id',
          builder: _builder(
            (state) => VisitorProfilePage(userId: state.pathParameters['id']!),
          ),
        ),
        GoRoute(
          path: '/settings',
          builder: _builder((_) => const SettingsPage()),
        ),
        GoRoute(
          path: '/settings/change-password',
          builder: _builder((_) => const ChangePasswordPage()),
        ),
        GoRoute(
          path: '/settings/account-switcher',
          builder: _builder((_) => const AccountSwitcherPage()),
        ),
        GoRoute(
          path: '/settings/account-settings',
          builder: _builder((_) => const AccountSettingsPage()),
        ),
        GoRoute(path: '/search', builder: _builder((_) => const SearchPage())),
        GoRoute(
          path: '/search/results',
          builder: (context, state) {
            final keywords = state.uri.queryParameters['keywords'] ?? '';
            return SearchResultsPage(keywords: keywords);
          },
        ),
        // 视频列表页面
        GoRoute(
          path: '/video/list',
          builder: (context, state) {
            final useSearch = state.uri.queryParameters['useSearch'] == 'true';
            final keywords = state.uri.queryParameters['keywords'];
            return VideoListPage(useSearch: useSearch, searchKeyword: keywords);
          },
        ),
      ],
      redirect: (context, state) {
        final auth = context.read<AuthProvider>();
        // 使用 canAttemptAutoLogin 判断是否允许进入受保护页面
        // 这样即使token过期，只要有refreshToken就允许进入，然后在后台刷新
        final canAccess = auth.isAuthenticated || auth.canAttemptAutoLogin;
        final loggingIn = state.matchedLocation.startsWith('/auth/');
        const protectedPrefixes = [
          '/home',
          '/video',
          '/create',
          '/messages',
          '/chat',
          '/profile',
          '/user',
        ];
        final wantsProtected = protectedPrefixes.any(
          (p) => state.matchedLocation.startsWith(p),
        );

        if (!canAccess && wantsProtected && !loggingIn) {
          return '/auth/login';
        }
        if (canAccess && loggingIn) {
          return '/home';
        }
        return null;
      },
    );
  }

  static GoRouterWidgetBuilder _builder(Widget Function(GoRouterState) page) {
    return (BuildContext context, GoRouterState state) => page(state);
  }
}
