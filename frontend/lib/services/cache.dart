import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 简易缓存管理：支持写入带TTL的数据，频繁请求（如热门视频）优先从缓存读取
class CacheManager {
  final SharedPreferences prefs;
  CacheManager(this.prefs);

  Future<void> setJson(String key, Object value, {Duration ttl = const Duration(minutes: 5)}) async {
    final payload = {
      'data': value,
      'expire_at': DateTime.now().add(ttl).millisecondsSinceEpoch,
    };
    await prefs.setString(key, jsonEncode(payload));
  }

  Map<String, dynamic>? getJson(String key) {
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final expireAt = decoded['expire_at'] as int?;
      if (expireAt != null && DateTime.now().millisecondsSinceEpoch < expireAt) {
        final data = decoded['data'];
        if (data is Map<String, dynamic>) return data;
        if (data is List) return {'items': data};
      }
    } catch (_) {}
    return null;
  }

  Future<bool> remove(String key) async {
    return prefs.remove(key);
  }
}