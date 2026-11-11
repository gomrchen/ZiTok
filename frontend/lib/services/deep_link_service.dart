import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// 深链：`zitok://drama/{id}?ep=` 或 path `/drama/{id}?ep=`
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  AppLinks? _links;
  StreamSubscription<Uri>? _sub;
  GoRouter? _router;
  bool _pluginMissing = false;

  void attach(GoRouter router) {
    _router = router;
    if (_pluginMissing) return;
    _sub?.cancel();
    try {
      _links ??= AppLinks();
      _sub = _links!.uriLinkStream.listen(
        _handle,
        onError: (Object e) {
          if (_isMissingPlugin(e)) {
            _pluginMissing = true;
            _sub?.cancel();
            _sub = null;
            if (kDebugMode) {
              debugPrint('DeepLink: app_links 未链接，需完整 rebuild');
            }
          }
        },
      );
      // 冷启动
      unawaited(_links!.getInitialLink().then((uri) {
        if (uri != null) _handle(uri);
      }).catchError((Object e) {
        if (_isMissingPlugin(e)) _pluginMissing = true;
      }));
    } catch (e) {
      if (_isMissingPlugin(e)) _pluginMissing = true;
      if (kDebugMode) debugPrint('DeepLink attach failed: $e');
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  static bool _isMissingPlugin(Object e) =>
      e is MissingPluginException ||
      '$e'.contains('MissingPluginException');

  void _handle(Uri uri) {
    final path = mapToAppPath(uri);
    if (path == null) return;
    final router = _router;
    if (router == null) return;
    try {
      router.go(path);
    } catch (e) {
      if (kDebugMode) debugPrint('DeepLink go failed: $e');
    }
  }

  /// 将自定义 scheme / https 映射为 go_router 路径
  static String? mapToAppPath(Uri uri) {
    // zitok://drama/123?ep=456
    if (uri.scheme == 'zitok') {
      final host = uri.host; // drama
      final segs = uri.pathSegments;
      if (host == 'drama' && segs.isNotEmpty) {
        final id = segs.first;
        final ep = uri.queryParameters['ep'];
        return ep == null || ep.isEmpty ? '/drama/$id' : '/drama/$id?ep=$ep';
      }
      // zitok:///drama/123
      if (segs.isNotEmpty && segs.first == 'drama' && segs.length >= 2) {
        final id = segs[1];
        final ep = uri.queryParameters['ep'];
        return ep == null || ep.isEmpty ? '/drama/$id' : '/drama/$id?ep=$ep';
      }
      // zitok://home | zitok://watching | zitok://theater
      if (host == 'home' || host == 'watching' || host == 'theater' || host == 'wallet') {
        return '/$host';
      }
      if (segs.length == 1 &&
          (segs.first == 'home' ||
              segs.first == 'watching' ||
              segs.first == 'theater' ||
              segs.first == 'wallet')) {
        return '/${segs.first}';
      }
      return null;
    }

    // https://zitok.app/drama/123?ep= 或纯 path
    if (uri.scheme == 'http' || uri.scheme == 'https' || uri.scheme.isEmpty) {
      final segs = uri.pathSegments;
      if (segs.length >= 2 && segs[0] == 'drama') {
        final id = segs[1];
        final ep = uri.queryParameters['ep'];
        return ep == null || ep.isEmpty ? '/drama/$id' : '/drama/$id?ep=$ep';
      }
      // 已是 app 内 path：/drama/1?ep=2
      if (uri.path.startsWith('/drama/')) {
        return uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
      }
    }
    return null;
  }
}
