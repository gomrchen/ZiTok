import 'package:flutter/foundation.dart';

/// 播放 / 字幕媒体 URL 校验（防 file:、javascript:、私网探测等）
bool isHttpMediaUrl(String raw) {
  final u = raw.trim();
  if (u.isEmpty || u.length > 4096) return false;
  final uri = Uri.tryParse(u);
  if (uri == null || !uri.hasScheme) return false;
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return false;
  if (uri.host.isEmpty) return false;
  return true;
}

/// 回环 / 链路本地 / RFC1918 私网（生产环境拒绝，防 SSRF 式内网探测）
bool isBlockedMediaHost(String host) {
  final h = host.toLowerCase().trim();
  if (h.isEmpty || h == 'localhost' || h == '::1') return true;
  if (h.endsWith('.local') || h.endsWith('.internal')) return true;

  final parts = h.split('.');
  if (parts.length != 4) return false;
  final nums = <int>[];
  for (final p in parts) {
    final n = int.tryParse(p);
    if (n == null || n < 0 || n > 255) return false;
    nums.add(n);
  }
  final a = nums[0];
  final b = nums[1];
  if (a == 0 || a == 10 || a == 127) return true;
  if (a == 169 && b == 254) return true;
  if (a == 172 && b >= 16 && b <= 31) return true;
  if (a == 192 && b == 168) return true;
  return false;
}

bool isProgressiveVideoUrl(String url) {
  final u = url.toLowerCase();
  if (u.contains('m3u8')) return false;
  return u.contains('.mp4') ||
      u.contains('.mov') ||
      u.contains('.m4v') ||
      u.contains('.webm');
}

/// [allowPrivateHosts] 默认跟随 [kDebugMode]（联调可用本机地址；Release 拒绝私网）
String? sanitizeHttpMediaUrl(String? raw, {bool? allowPrivateHosts}) {
  if (raw == null) return null;
  final u = raw.trim();
  if (!isHttpMediaUrl(u)) return null;
  final uri = Uri.parse(u);
  final allowPrivate = allowPrivateHosts ?? kDebugMode;
  if (!allowPrivate && isBlockedMediaHost(uri.host)) return null;
  return u;
}

/// 用户可见错误，避免把 Dio/栈/服务端原文直接甩到 UI
String playerFriendlyError(Object e, {String fallback = '加载失败，请稍后重试'}) {
  final s = '$e';
  if (s.contains('网络') || s.toLowerCase().contains('socket')) {
    return '网络异常，请检查连接后重试';
  }
  if (s.contains('empty url') || s.contains('invalid url')) {
    return '播放地址无效';
  }
  return fallback;
}
