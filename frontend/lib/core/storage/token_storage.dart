/*
 * 文件版本号: 1.0.0
 * 文件功能说明: 用户认证Token存储管理类，负责访问令牌和刷新令牌的安全存储、获取和管理
 * 当前已知问题:
 *   - Token以明文形式存储，存在安全风险
 *   - 缺少Token有效期自动检查机制
 *   - 没有Token泄露检测和防护措施
 * 修改需求说明:
 *   - 实现Token加密存储，提高安全性
 *   - 添加Token有效期自动检查和预警功能
 *   - 集成Token安全检测机制，防止泄露
 *   - 支持多设备Token管理和同步
 */

import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

/// Token存储管理
/// 负责访问令牌和刷新令牌的本地存储和管理
class TokenStorage {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _tokenExpiryKey = 'token_expiry';
  
  /// 保存令牌
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    DateTime? expiryTime,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setString(_accessTokenKey, accessToken);
      await prefs.setString(_refreshTokenKey, refreshToken);
      
      if (expiryTime != null) {
        await prefs.setInt(_tokenExpiryKey, expiryTime.millisecondsSinceEpoch);
      }
      
      AppLogger.info('Token保存成功');
    } catch (e) {
      AppLogger.error('Token保存失败', e);
      rethrow;
    }
  }
  
  /// 获取访问令牌
  Future<String?> getAccessToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_accessTokenKey);
      
      if (token != null && await isTokenValid()) {
        return token;
      }
      
      return null;
    } catch (e) {
      AppLogger.error('获取访问令牌失败', e);
      return null;
    }
  }
  
  /// 获取刷新令牌
  Future<String?> getRefreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_refreshTokenKey);
    } catch (e) {
      AppLogger.error('获取刷新令牌失败', e);
      return null;
    }
  }
  
  /// 检查令牌是否有效
  Future<bool> isTokenValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiryTimestamp = prefs.getInt(_tokenExpiryKey);
      
      if (expiryTimestamp == null) {
        // 如果没有过期时间，假设令牌有效
        return true;
      }
      
      final expiryTime = DateTime.fromMillisecondsSinceEpoch(expiryTimestamp);
      final now = DateTime.now();
      
      // 提前5分钟判断过期，给刷新留出时间
      final isValid = now.isBefore(expiryTime.subtract(const Duration(minutes: 5)));
      
      if (!isValid) {
        AppLogger.warning('访问令牌即将过期或已过期');
      }
      
      return isValid;
    } catch (e) {
      AppLogger.error('检查令牌有效性失败', e);
      return false;
    }
  }
  
  /// 检查是否已登录
  Future<bool> isLoggedIn() async {
    final accessToken = await getAccessToken();
    final refreshToken = await getRefreshToken();
    
    return accessToken != null && refreshToken != null;
  }
  
  /// 清除所有令牌
  Future<void> clearTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.remove(_accessTokenKey);
      await prefs.remove(_refreshTokenKey);
      await prefs.remove(_tokenExpiryKey);
      
      AppLogger.info('所有令牌已清除');
    } catch (e) {
      AppLogger.error('清除令牌失败', e);
      rethrow;
    }
  }
  
  /// 获取令牌过期时间
  Future<DateTime?> getTokenExpiryTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiryTimestamp = prefs.getInt(_tokenExpiryKey);
      
      if (expiryTimestamp != null) {
        return DateTime.fromMillisecondsSinceEpoch(expiryTimestamp);
      }
      
      return null;
    } catch (e) {
      AppLogger.error('获取令牌过期时间失败', e);
      return null;
    }
  }
}