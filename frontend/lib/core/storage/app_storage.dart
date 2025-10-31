/*
 * 文件版本号: 1.0.0
 * 文件功能说明: 应用本地存储管理类，基于SharedPreferences实现用户偏好设置、应用配置等数据的持久化存储
 * 当前已知问题:
 *   - 缺少数据加密机制，敏感信息存储不安全
 *   - 没有数据迁移和版本管理机制
 *   - 缺少存储空间管理和清理功能
 * 修改需求说明:
 *   - 添加敏感数据加密存储功能
 *   - 实现数据版本管理和迁移机制
 *   - 添加存储空间监控和自动清理功能
 *   - 支持数据备份和恢复功能
 */

import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

/// 应用存储管理
/// 负责应用配置、用户偏好设置等数据的本地存储
class AppStorage {
  // 主题相关
  static const String _themeKey = 'app_theme';
  static const String _languageKey = 'app_language';
  
  // 用户偏好
  static const String _autoPlayVideoKey = 'auto_play_video';
  static const String _pushNotificationKey = 'push_notification';
  static const String _dataUsageKey = 'data_usage_mode';
  
  // 缓存相关
  static const String _cacheVersionKey = 'cache_version';
  static const String _lastUpdateKey = 'last_update';
  
  /// 保存主题模式
  Future<void> saveThemeMode(String themeMode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, themeMode);
      AppLogger.info('主题模式已保存: $themeMode');
    } catch (e) {
      AppLogger.error('保存主题模式失败', e);
      rethrow;
    }
  }
  
  /// 获取主题模式
  Future<String> getThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_themeKey) ?? 'system';
    } catch (e) {
      AppLogger.error('获取主题模式失败', e);
      return 'system';
    }
  }
  
  /// 保存语言设置
  Future<void> saveLanguage(String languageCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, languageCode);
      AppLogger.info('语言设置已保存: $languageCode');
    } catch (e) {
      AppLogger.error('保存语言设置失败', e);
      rethrow;
    }
  }
  
  /// 获取语言设置
  Future<String> getLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_languageKey) ?? 'zh';
    } catch (e) {
      AppLogger.error('获取语言设置失败', e);
      return 'zh';
    }
  }
  
  /// 保存自动播放视频设置
  Future<void> saveAutoPlayVideo(bool autoPlay) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_autoPlayVideoKey, autoPlay);
      AppLogger.info('自动播放视频设置已保存: $autoPlay');
    } catch (e) {
      AppLogger.error('保存自动播放视频设置失败', e);
      rethrow;
    }
  }
  
  /// 获取自动播放视频设置
  Future<bool> getAutoPlayVideo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_autoPlayVideoKey) ?? true;
    } catch (e) {
      AppLogger.error('获取自动播放视频设置失败', e);
      return true;
    }
  }
  
  /// 保存推送通知设置
  Future<void> savePushNotification(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_pushNotificationKey, enabled);
      AppLogger.info('推送通知设置已保存: $enabled');
    } catch (e) {
      AppLogger.error('保存推送通知设置失败', e);
      rethrow;
    }
  }
  
  /// 获取推送通知设置
  Future<bool> getPushNotification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_pushNotificationKey) ?? true;
    } catch (e) {
      AppLogger.error('获取推送通知设置失败', e);
      return true;
    }
  }
  
  /// 保存数据使用模式
  Future<void> saveDataUsageMode(String mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dataUsageKey, mode);
      AppLogger.info('数据使用模式已保存: $mode');
    } catch (e) {
      AppLogger.error('保存数据使用模式失败', e);
      rethrow;
    }
  }
  
  /// 获取数据使用模式
  Future<String> getDataUsageMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_dataUsageKey) ?? 'normal';
    } catch (e) {
      AppLogger.error('获取数据使用模式失败', e);
      return 'normal';
    }
  }
  
  /// 保存缓存版本
  Future<void> saveCacheVersion(int version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_cacheVersionKey, version);
      AppLogger.info('缓存版本已保存: $version');
    } catch (e) {
      AppLogger.error('保存缓存版本失败', e);
      rethrow;
    }
  }
  
  /// 获取缓存版本
  Future<int> getCacheVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_cacheVersionKey) ?? 1;
    } catch (e) {
      AppLogger.error('获取缓存版本失败', e);
      return 1;
    }
  }
  
  /// 保存最后更新时间
  Future<void> saveLastUpdateTime(DateTime time) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastUpdateKey, time.millisecondsSinceEpoch);
      AppLogger.info('最后更新时间已保存: $time');
    } catch (e) {
      AppLogger.error('保存最后更新时间失败', e);
      rethrow;
    }
  }
  
  /// 获取最后更新时间
  Future<DateTime?> getLastUpdateTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_lastUpdateKey);
      
      if (timestamp != null) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      
      return null;
    } catch (e) {
      AppLogger.error('获取最后更新时间失败', e);
      return null;
    }
  }
  
  /// 清除所有存储数据
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      AppLogger.info('所有存储数据已清除');
    } catch (e) {
      AppLogger.error('清除存储数据失败', e);
      rethrow;
    }
  }
}