import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/video_playback_manager.dart';
import '../views/welcome/welcome_page.dart';
import '../views/auth/login_page.dart';
import '../views/auth/register_page.dart';
import '../views/auth/forgot_password_page.dart';
import '../views/home/home_shell.dart';
import '../views/messages/messages_page.dart';
import '../views/chat/chat_page.dart';
import '../views/profile/edit_profile_page.dart';
import '../views/settings/settings_page.dart';
import '../views/search/search_page.dart';
import '../views/search/search_results_page.dart';
import '../views/settings/change_password_page.dart';
import '../views/settings/account_switcher_page.dart';
import '../views/settings/account_settings_page.dart';
import '../views/profile/visitor_profile_page.dart';
import '../views/drama/drama_detail_page.dart';
import '../views/drama/player_pip.dart';
import '../views/drama/wallet_page.dart';
import '../views/drama/theater_page.dart';
import '../views/drama/watching_page.dart';

class AppRouter {
  static GoRouter buildRouter(AuthProvider auth) {
    return GoRouter(
      initialLocation: '/welcome',
      refreshListenable: null,
      observers: [VideoRouteObserver.instance],
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
        GoRoute(
          path: '/home',
          builder: (context, state) {
            final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0;
            return HomeShell(initialTab: tab);
          },
        ),
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
        GoRoute(
          path: '/drama/:id',
          builder: _builder(
            (state) => DramaDetailPage(
              dramaId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
              initialEpisodeId: int.tryParse(state.uri.queryParameters['ep'] ?? ''),
            ),
          ),
        ),
        GoRoute(path: '/wallet', builder: _builder((_) => const WalletPage())),
        GoRoute(
          path: '/theater',
          builder: _builder((state) {
            final cat = state.uri.queryParameters['category']?.trim();
            return TheaterPage(initialCategory: (cat == null || cat.isEmpty) ? null : cat);
          }),
        ),
        GoRoute(path: '/watching', builder: _builder((_) => const WatchingPage())),
        // 旧 /video /note /create 路由统一回首页，避免深链崩溃
        GoRoute(path: '/video/:id', redirect: (_, __) => '/home'),
        GoRoute(path: '/video/list', redirect: (_, __) => '/theater'),
        GoRoute(path: '/note/:id', redirect: (_, __) => '/home'),
        GoRoute(path: '/create', redirect: (_, __) => '/home'),
        GoRoute(
          path: '/profile/edit',
          builder: _builder((_) => const EditProfilePage()),
        ),
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
      ],
      redirect: (context, state) {
        final auth = context.read<AuthProvider>();
        final canAccess = auth.isAuthenticated || auth.canAttemptAutoLogin;
        final loggingIn = state.matchedLocation.startsWith('/auth/');
        const protectedPrefixes = [
          '/home',
          '/drama',
          '/wallet',
          '/messages',
          '/chat',
          '/profile',
          '/user',
          '/settings',
          '/watching',
          '/theater',
          '/search',
        ];
        final wantsProtected = protectedPrefixes.any(
          (p) => state.matchedLocation.startsWith(p),
        );

        // 已退出：禁止停留在业务页，并关掉离页小窗
        if (!canAccess && wantsProtected && !loggingIn) {
          if (PlayerPipController.isOpen) {
            PlayerPipController.close(disposeHandle: true);
          }
          return '/auth/login';
        }
        // 登录中页：已登录则回首页
        if (auth.isAuthenticated && loggingIn) {
          return '/home';
        }
        // 欢迎页：仅真正已登录才跳过（不能用 canAttemptAutoLogin，避免退出后被顶回）
        if (auth.isAuthenticated && state.matchedLocation == '/welcome') {
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
