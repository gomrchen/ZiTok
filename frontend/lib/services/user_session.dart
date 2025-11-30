import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_models.dart';

/// 统一的用户会话管理服务
///
/// 这是获取当前用户 ID 和 Token 的唯一真实来源 (Single Source of Truth)。
/// 所有需要用户 ID 或 Token 的地方都应该通过此服务获取。
class UserSession extends ChangeNotifier {
  static UserSession? _instance;

  /// 获取单例实例
  static UserSession get instance {
    _instance ??= UserSession._();
    return _instance!;
  }

  /// 重置实例（仅用于测试）
  @visibleForTesting
  static void resetInstance() {
    _instance = null;
  }

  UserSession._();

  String? _userId;
  User? _user;
  String? _accessToken;
  String? _refreshToken;
  bool _isInitialized = false;

  /// 当前用户 ID（唯一获取方式）
  String? get userId => _userId;

  /// 当前用户信息
  User? get user => _user;

  /// 当前访问令牌
  String? get accessToken => _accessToken;

  /// 当前刷新令牌
  String? get refreshToken => _refreshToken;

  /// 是否已登录（必须同时有用户ID和有效token）
  bool get isLoggedIn =>
      _userId != null && _userId!.isNotEmpty && _accessToken != null && _accessToken!.isNotEmpty;

  /// 是否有有效的访问令牌
  bool get hasValidToken => _accessToken != null && _accessToken!.isNotEmpty;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 用户 ID（非空版本，仅在确定已登录时使用）
  ///
  /// 如果未登录会抛出异常，请先检查 [isLoggedIn]
  String get requireUserId {
    if (!isLoggedIn) {
      throw StateError('用户未登录，无法获取用户ID');
    }
    return _userId!;
  }

  /// 从持久化存储恢复会话
  ///
  /// 应在应用启动时调用
  Future<void> restoreSession(SharedPreferences prefs) async {
    _userId = prefs.getString('user_id');
    _accessToken = prefs.getString('access_token');
    _refreshToken = prefs.getString('refresh_token');
    _isInitialized = true;
    notifyListeners();
  }

  /// 设置当前用户（登录成功后调用）
  Future<void> setUser(User user, SharedPreferences prefs,
      {String? accessToken, String? refreshToken}) async {
    _userId = user.id;
    _user = user;
    await prefs.setString('user_id', user.id);

    // 如果提供了 token，同时保存
    if (accessToken != null && accessToken.isNotEmpty) {
      _accessToken = accessToken;
      await prefs.setString('access_token', accessToken);
    }
    if (refreshToken != null && refreshToken.isNotEmpty) {
      _refreshToken = refreshToken;
      await prefs.setString('refresh_token', refreshToken);
    }
    notifyListeners();
  }

  /// 设置令牌（用于刷新令牌后更新）
  Future<void> setTokens(SharedPreferences prefs,
      {required String accessToken, String? refreshToken}) async {
    _accessToken = accessToken;
    await prefs.setString('access_token', accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      _refreshToken = refreshToken;
      await prefs.setString('refresh_token', refreshToken);
    }
    notifyListeners();
  }

  /// 仅更新用户 ID（用于兼容旧代码）
  Future<void> setUserId(String userId, SharedPreferences prefs) async {
    _userId = userId;
    await prefs.setString('user_id', userId);
    notifyListeners();
  }

  /// 更新用户信息（不改变 ID）
  void updateUser(User user) {
    if (_userId != user.id) {
      throw ArgumentError('更新的用户 ID 与当前会话不匹配');
    }
    _user = user;
    notifyListeners();
  }

  /// 清除会话（登出时调用）
  Future<void> clear(SharedPreferences prefs) async {
    _userId = null;
    _user = null;
    _accessToken = null;
    _refreshToken = null;
    await prefs.remove('user_id');
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    notifyListeners();
  }

  @override
  String toString() {
    return 'UserSession(userId: $_userId, isLoggedIn: $isLoggedIn)';
  }
}
