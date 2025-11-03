import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../views/welcome/welcome_page.dart';
import '../views/auth/login_page.dart';
import '../views/auth/register_page.dart';
import '../views/home/home_shell.dart';
import '../views/video/video_detail_page.dart';
import '../views/notes/video_notes_page.dart';
import '../views/messages/messages_page.dart';
import '../views/chat/chat_page.dart';
import '../views/profile/edit_profile_page.dart';
import '../views/settings/settings_page.dart';

class AppRouter {
  static GoRouter buildRouter(AuthProvider auth) {
    return GoRouter(
      initialLocation: '/welcome',
      refreshListenable: auth,
      routes: [
        GoRoute(path: '/welcome', builder: _builder((_) => const WelcomePage())),
        GoRoute(path: '/auth/login', builder: _builder((_) => const LoginPage())),
        GoRoute(path: '/auth/register', builder: _builder((_) => const RegisterPage())),
        // 统一主界面（组件化四模块）
        GoRoute(path: '/home', builder: _builder((_) => const HomeShell())),
        // 消息列表与聊天
        GoRoute(path: '/messages', builder: _builder((_) => const MessagesPage())),
        GoRoute(path: '/chat/:cid', builder: _builder((state) => ChatPage(conversationId: state.pathParameters['cid']!))),
        GoRoute(path: '/friends/search', builder: _builder((_) => const FriendSearchPage())),
        // 非主界面详情页与设置
        GoRoute(path: '/video/:id', builder: _builder((state) => VideoDetailPage(id: state.pathParameters['id']!))),
        GoRoute(path: '/video/:id/notes', builder: _builder((state) => VideoNotesPage(videoId: state.pathParameters['id']!))),
        GoRoute(path: '/profile/edit', builder: _builder((_) => const EditProfilePage())),
        GoRoute(path: '/settings', builder: _builder((_) => const SettingsPage())),
      ],
      redirect: (context, state) {
        final isLoggedIn = context.read<AuthProvider>().isAuthenticated;
        final loggingIn = state.matchedLocation.startsWith('/auth/');
        const protectedPrefixes = ['/home', '/video', '/create', '/messages', '/chat', '/profile'];
        final wantsProtected = protectedPrefixes.any((p) => state.matchedLocation.startsWith(p));

        if (!isLoggedIn && wantsProtected && !loggingIn) {
          return '/auth/login';
        }
        if (isLoggedIn && loggingIn) {
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