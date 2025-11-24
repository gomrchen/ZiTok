import '../config/env.dart';

class UrlUtils {
  static String _origin() {
    final u = Uri.parse(Env.baseUrl);
    final port = (u.hasPort && u.port != 0) ? ':${u.port}' : '';
    return '${u.scheme}://${u.host}$port';
  }

  static String resolveStorageUrl(String? raw, {String defaultDir = 'videos'}) {
    if (raw == null || raw.isEmpty) return '';
    final s = raw.trim();
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    final fname = s.split('/').last;
    String dir = defaultDir;
    if (s.contains('/avatars/')) dir = 'avatars';
    if (s.contains('/covers/')) dir = 'covers';
    if (s.contains('/videos/')) dir = 'videos';
    return '${_origin()}/$dir/$fname';
  }
}
