import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// 深链：`zitok://drama/{id}?ep=` 或 path `/drama/{id}?ep=`
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  static const _allowedHttpsHosts = <String>{
    'zitok.app',
    'www.zitok.app',
  };

  AppLinks? _links;
  StreamSubscription<Uri>? _sub;
  GoRouter? _router;
  bool _pluginMissing = false;
  String? _lastHandled;
  DateTime? _lastHandledAt;

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
    _router = null;
  }

  static bool _isMissingPlugin(Object e) =>
      e is MissingPluginException ||
      '$e'.contains('MissingPluginException');

  void _handle(Uri uri) {
    final path = mapToAppPath(uri);
    if (path == null) return;
    final now = DateTime.now();
    if (_lastHandled == path &&
        _lastHandledAt != null &&
        now.difference(_lastHandledAt!) < const Duration(milliseconds: 800)) {
      return;
    }
    _lastHandled = path;
    _lastHandledAt = now;
    final router = _router;
    if (router == null) return;
    try {
      router.go(path);
    } catch (e) {
      if (kDebugMode) debugPrint('DeepLink go failed: $e');
    }
  }

  /// 分享 / 海报用的统一深链文案
  static String buildDramaEpisodeLink({required int dramaId, required int episodeId}) {
    if (dramaId <= 0) return 'zitok://home';
    if (episodeId <= 0) return 'zitok://drama/$dramaId';
    return 'zitok://drama/$dramaId?ep=$episodeId';
  }

  static bool _isDigits(String? s) {
    if (s == null || s.isEmpty) return false;
    if (s.length > 18) return false;
    for (var i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      if (c < 0x30 || c > 0x39) return false;
    }
    return true;
  }

  static String? _dramaPath(String id, String? ep) {
    if (!_isDigits(id)) return null;
    if (ep == null || ep.isEmpty) return '/drama/$id';
    if (!_isDigits(ep)) return '/drama/$id';
    return '/drama/$id?ep=$ep';
  }

  /// 将自定义 scheme / https 映射为 go_router 路径
  static String? mapToAppPath(Uri uri) {
    if (uri.scheme == 'zitok') {
      final host = uri.host;
      final segs = uri.pathSegments;
      if (host == 'drama' && segs.isNotEmpty) {
        return _dramaPath(segs.first, uri.queryParameters['ep']);
      }
      if (segs.isNotEmpty && segs.first == 'drama' && segs.length >= 2) {
        return _dramaPath(segs[1], uri.queryParameters['ep']);
      }
      const tabs = {'home', 'watching', 'theater', 'wallet'};
      if (tabs.contains(host)) return '/$host';
      if (segs.length == 1 && tabs.contains(segs.first)) return '/${segs.first}';
      return null;
    }

    if (uri.scheme == 'http' || uri.scheme == 'https') {
      if (!_allowedHttpsHosts.contains(uri.host.toLowerCase())) return null;
      final segs = uri.pathSegments;
      if (segs.length >= 2 && segs[0] == 'drama') {
        return _dramaPath(segs[1], uri.queryParameters['ep']);
      }
      return null;
    }

    // 仅允许应用内纯 path（scheme 为空）
    if (uri.scheme.isEmpty && uri.path.startsWith('/drama/')) {
      final segs = uri.pathSegments;
      if (segs.length >= 2 && segs[0] == 'drama') {
        return _dramaPath(segs[1], uri.queryParameters['ep']);
      }
    }
    return null;
  }
}
