import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 搜索历史服务：管理视频搜索历史的本地缓存
class SearchHistoryService {
  static const String _key = 'video_search_history';
  static const int _maxHistoryCount = 20; // 最多保存20条历史记录

  final SharedPreferences _prefs;

  SearchHistoryService(this._prefs);

  /// 获取搜索历史列表
  List<String> getHistory() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.cast<String>();
      }
    } catch (_) {}
    return [];
  }

  /// 添加搜索记录
  /// 如果已存在则移到最前面，否则添加到最前面
  Future<void> addHistory(String keyword) async {
    if (keyword.trim().isEmpty) return;

    final history = getHistory();
    final trimmed = keyword.trim();

    // 移除已存在的相同记录
    history.remove(trimmed);

    // 添加到最前面
    history.insert(0, trimmed);

    // 限制最大数量
    if (history.length > _maxHistoryCount) {
      history.removeRange(_maxHistoryCount, history.length);
    }

    await _prefs.setString(_key, jsonEncode(history));
  }

  /// 删除单条搜索记录
  Future<void> removeHistory(String keyword) async {
    final history = getHistory();
    history.remove(keyword);
    await _prefs.setString(_key, jsonEncode(history));
  }

  /// 清空所有搜索历史
  Future<void> clearHistory() async {
    await _prefs.remove(_key);
  }
}
