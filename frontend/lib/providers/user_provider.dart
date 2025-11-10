import 'package:flutter/material.dart';
import '../repositories/user_repository.dart';
import '../models/user_models.dart';

/// 用户状态管理器 (Provider)
///
/// 负责:
/// 1. 获取和管理当前登录用户的信息。
/// 2. 获取和缓存其他用户的信息，以供App各处使用。
class UserProvider with ChangeNotifier {
  final UserRepository _userRepository;

  // UserProvider( this._userRepository);
  UserProvider({required UserRepository repo}) : _userRepository = repo;

  // ========== 状态属性 ==========

  /// 当前登录的用户信息
  UserInfo? _currentUser;

  /// 其他用户的缓存，以用户ID (String) 为key
  final Map<String, UserInfo> _userCache = {};


  /// 全局错误信息
  String? _error;


  // ========== Getters ==========

  /// 获取当前登录的用户信息
  UserInfo? get currentUser => _currentUser;

  /// 获取错误信息
  String? get error => _error;


  // ========== Public Methods ==========

  /// 获取并更新当前登录的用户信息
  ///
  /// 这个方法专门用于登录后设置当前用户信息。
  /// [uid] 当前登录用户的ID (String)。
  Future<void> fetchCurrentUser(String uid) async {
    // 调用通用的 getUserInfo 方法来获取用户信息
    final userInfo = await getUserInfo(uid);
    if (userInfo != null) {
      _currentUser = userInfo;
      notifyListeners(); // 更新当前用户信息后通知UI
    }
  }

  /// 通用方法：根据UID获取任何用户的信息
  ///
  /// 优先从缓存中读取，如果缓存中没有，则通过网络请求获取，并存入缓存。
  /// [uid] 需要获取信息的用户ID (String)。
  Future<UserInfo?> getUserInfo(String uid) async {
    print('开始获取用户(ID: $uid)信息...');
    // 1. 优先从缓存中查找
    if (_userCache.containsKey(uid)) {
      return _userCache[uid];
    }

    try {
      // 调用 repository 中的 info 方法
      final userInfo = await _userRepository.info(uid: uid);

      // 3. 将获取到的用户信息存入缓存
      _userCache[uid] = userInfo;
      return userInfo;
    } catch (e) {
      _error = '获取用户(ID: $uid)信息失败: $e';
      print(_error); // 在调试控制台打印错误
      return null; // 出错时返回null
    }
  }

  /// 清除当前用户信息（例如，在用户登出时调用）
  void clearCurrentUser() {
    _currentUser = null;
    notifyListeners();
  }

  // ========== Private Helper ==========

}
