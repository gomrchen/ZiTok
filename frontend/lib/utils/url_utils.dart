import '../config/env.dart';

class UrlUtils {
  static String _origin() {
    final u = Uri.parse(Env.baseUrl);
    final port = (u.hasPort && u.port != 0) ? ':${u.port}' : '';
    return '${u.scheme}://${u.host}$port';
  }

  static final _storageDirs = {'avatars', 'covers', 'videos', 'chat'};

  /// 将后端返回的相对/绝对存储地址统一改写为当前 [Env.baseUrl] 的 origin。
  ///
  /// 历史数据常见错误：`http://localhost:8080/avatars/xxx.jpg`（端口/主机与网关不一致），
  /// 绝对地址若原样使用会导致头像「上传成功但不显示」。
  static String resolveStorageUrl(String? raw, {String defaultDir = 'videos'}) {
    if (raw == null || raw.isEmpty) return '';
    final s = raw.trim();

    String? dir;
    String? fname;

    if (s.startsWith('http://') || s.startsWith('https://')) {
      final u = Uri.tryParse(s);
      if (u == null || u.path.isEmpty) return s;
      final segs = u.pathSegments.where((e) => e.isNotEmpty).toList();
      if (segs.isEmpty) return s;
      // /avatars/xxx.jpg 或 /api/... 以外的本地存储路径
      if (segs.length >= 2 && _storageDirs.contains(segs[segs.length - 2])) {
        dir = segs[segs.length - 2];
        fname = segs.last;
      } else if (segs.length == 1 && _storageDirs.contains(defaultDir)) {
        // 某些实现只存文件名但给了错误绝对域
        dir = defaultDir;
        fname = segs.last;
      } else {
        // 外链 CDN 等，保持原样
        return s;
      }
    } else {
      final segs = s.split('/').where((e) => e.isNotEmpty).toList();
      if (segs.isEmpty) return '';
      fname = segs.last;
      dir = defaultDir;
      for (final d in _storageDirs) {
        if (s.contains('/$d/') || s.startsWith('$d/') || segs.contains(d)) {
          dir = d;
          break;
        }
      }
    }

    final name = fname.trim();
    if (name.isEmpty) return '';
    return '${_origin()}/${dir ?? defaultDir}/$name';
  }
}
