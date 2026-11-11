/// 播放 / 字幕媒体 URL 校验（防 file:、javascript: 等）
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

bool isProgressiveVideoUrl(String url) {
  final u = url.toLowerCase();
  if (u.contains('m3u8')) return false;
  return u.contains('.mp4') ||
      u.contains('.mov') ||
      u.contains('.m4v') ||
      u.contains('.webm');
}

String? sanitizeHttpMediaUrl(String? raw) {
  if (raw == null) return null;
  final u = raw.trim();
  if (!isHttpMediaUrl(u)) return null;
  return u;
}

/// 用户可见错误，避免把 Dio/栈信息直接甩到 UI
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
