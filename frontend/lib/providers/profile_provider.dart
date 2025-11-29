import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_models.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../repositories/user_repository.dart';
import '../services/user_service.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

import 'auth_provider.dart'; // 或者 'package:flutter/widgets.dart'

class ProfileProvider extends ChangeNotifier {
  final UserRepository repo;
  User? _user;
  bool _loading = false;
  String? _error;
  double _avatarProgress = 0;
  double _backgroundProgress = 0;
  Timer? _debounce;
  ProfileProvider({required this.repo});

  int _followersCount = 0;
  int _followingsCount = 0;
  bool _loadingStats = false;
  String? _statsError;

  User? get user => _user;
  bool get loading => _loading;
  String? get error => _error;
  double get avatarUploadProgress => _avatarProgress;
  double get backgroundUploadProgress => _backgroundProgress;

  int get followersCount => _followersCount;
  int get followingsCount => _followingsCount;
  bool get loadingStats => _loadingStats;
  String? get statsError => _statsError;

  Future<void> loadUserStats({String? userId}) async {
    if (_loadingStats) return;

    String? targetUserId = userId ?? _user?.id;
    if (targetUserId == null || targetUserId.isEmpty) {
      print('⚠️ ProfileProvider.loadUserStats: 无法获取用户ID');
      return;
    }

    _loadingStats = true;
    _statsError = null;
    notifyListeners();

    try {
      print('🔍 ProfileProvider.loadUserStats: 开始加载用户统计数据，userId: $targetUserId');

      // 分别获取粉丝和关注数量，以便单独调试
      print('🔄 开始获取粉丝数量...');
      final followersCount = await repo.getFollowersCount(userId: targetUserId);
      print('🔄 开始获取关注数量...');
      final followingsCount = await repo.getFollowingsCount(userId: targetUserId);

      _followersCount = followersCount;
      _followingsCount = followingsCount;

      print('✅ ProfileProvider.loadUserStats: 加载完成 - 粉丝: $_followersCount, 关注: $_followingsCount');
    } catch (e) {
      _statsError = e.toString();
      print('❌ ProfileProvider.loadUserStats 错误: $e');
      // 设置默认值避免显示0
      _followersCount = 0;
      _followingsCount = 0;
    } finally {
      _loadingStats = false;
      notifyListeners();
    }
  }

  Future<void> loadFromAuthProvider(BuildContext context) async {
    print('🔄 ProfileProvider: 开始从AuthProvider加载用户数据');

    try {
      final authProvider = context.read<AuthProvider>();
      print('🔍 ProfileProvider: AuthProvider状态 - user: ${authProvider.user != null ? "非空" : "空"}');

      if (authProvider.user != null && authProvider.user!.id.isNotEmpty) {
        print("🔍 ProfileProvider: 从AuthProvider获取用户ID: ${authProvider.user!.id}");
        await load(userId: authProvider.user!.id);
      } else {
        print("⚠️ ProfileProvider: AuthProvider中没有用户数据，尝试从缓存加载");
        await loadFromCache();
      }
    } catch (e) {
      print('❌ ProfileProvider.loadFromAuthProvider 错误: $e');
      _error = '加载用户数据失败: $e';
      notifyListeners();
    }
  }

  Future<void> load({String? userId}) async {
    // 如果userId为null，尝试从本地存储获取
    String? targetUserId = userId;
    if (targetUserId == null) {
      final box = Hive.box('user_box');
      targetUserId = box.get('id') as String?;

      // 如果Hive中没有，尝试从SharedPreferences获取
      if (targetUserId == null) {
        final prefs = await SharedPreferences.getInstance();
        targetUserId = prefs.getString('auth_user_id');
      }

      if (kDebugMode) {
        print('🔍 ProfileProvider.load: 从本地存储获取userId: $targetUserId');
      }
    }

    // 如果仍然为null，设置一个默认值或报错
    if (targetUserId == null || targetUserId.isEmpty) {
      if (kDebugMode) {
        print('⚠️ ProfileProvider.load: 无法获取用户ID，跳过加载');
      }
      _error = '无法获取用户ID，请先登录';
      _loading = false;
      notifyListeners();
      return;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    if (kDebugMode) {
      print('🔍 ProfileProvider.load: 开始加载用户数据，userId: $targetUserId');
    }

    try {
      _user = await repo.info(userId: targetUserId);

      if (kDebugMode) {
        print('✅ ProfileProvider.load: 成功加载用户数据: ${_user?.username}');
        print('📊 用户信息详情: id=${_user?.id}, username=${_user?.username}, avatar=${_user?.avatarUrl}');
      }

      if (_user != null) {
        final box = Hive.box('user_box');
        await box.put('id', _user!.id);
        await box.put('username', _user!.username);
        await box.put('avatar_url', _user!.avatarUrl);
        await box.put('background_url', _user!.profileBackgroundImageUrl);
        await box.put('bio', _user!.bio);
        await box.put('gender', switch (_user!.gender) { Gender.male => 1, Gender.female => 2, _ => 0 });
        await box.put('birthday', _user!.birthday);

        unawaited(loadUserStats(userId: _user!.id));

        if (kDebugMode) {
          print('💾 ProfileProvider.load: 用户数据已保存到本地存储');
        }
      } else {
        if (kDebugMode) {
          print('❌ ProfileProvider.load: 用户数据为空');
        }
        _error = '用户数据为空';
      }
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('❌ ProfileProvider.load: 加载用户数据失败: $e');
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadFromCache() async {
    print("🔄 ProfileProvider: 尝试从缓存加载用户数据");

    // 首先尝试从 SharedPreferences 获取用户ID
    final prefs = await SharedPreferences.getInstance();
    final String? cachedUserId = prefs.getString('auth_user_id');

    if (cachedUserId != null && cachedUserId.isNotEmpty) {
      print("📦 ProfileProvider: 从SharedPreferences获取userId: $cachedUserId");
      await load(userId: cachedUserId);
    } else {
      // 如果 SharedPreferences 中没有，尝试从 Hive 获取
      final box = Hive.box('user_box');
      final String? hiveUserId = box.get('id') as String?;

      if (hiveUserId != null && hiveUserId.isNotEmpty) {
        print("📦 ProfileProvider: 从Hive获取userId: $hiveUserId");
        await load(userId: hiveUserId);
      } else {
        print("❌ ProfileProvider: 缓存中没有用户数据");
        _error = '无法获取用户ID，请先登录';
        notifyListeners();
      }
    }
  }

  void updateLocal(User next) {
    _user = next;
    notifyListeners();
  }

  // 在 profile_provider.dart 的 debounceUpdateInfo 方法中
  void debounceUpdateInfo({String? username, String? signature, int? gender, String? birthday, String? avatarUrl, String? backgroundUrl}) {
    final u = _user;
    if (u == null) return;

    // 将 int? 转换为 Gender 枚举
    final Gender gEnum;
    switch (gender) {
      case 1:
        gEnum = Gender.male;
        break;
      case 2:
        gEnum = Gender.female;
        break;
      case null:
      default:
        gEnum = Gender.unknown;
    }

    final updated = u.copyWith(
      username: username ?? u.username,
      bio: signature ?? u.bio,
      avatarUrl: avatarUrl ?? u.avatarUrl,
      profileBackgroundImageUrl: backgroundUrl ?? u.profileBackgroundImageUrl,
      gender: gender == null ? u.gender : gEnum, // 使用转换后的枚举
      birthday: birthday ?? u.birthday,
    );

    updateLocal(updated);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        await repo.updateInfo(UserUpdateRequest(
          username: username,
          signature: signature,
          gender: gender,
          birthday: birthday,
          avatarUrl: avatarUrl,
          backgroundUrl: backgroundUrl,
        ));
        final box = Hive.box('user_box');
        await box.put('username', updated.username);
        await box.put('bio', updated.bio);
        await box.put('avatar_url', updated.avatarUrl);
        await box.put('background_url', updated.profileBackgroundImageUrl);
        await box.put('gender', switch (updated.gender) { Gender.male => 1, Gender.female => 2, _ => 0 });
        await box.put('birthday', updated.birthday);
      } catch (e) {
        _error = e.toString();
        notifyListeners();
      }
    });
  }

  Future<void> uploadAvatar(MultipartFile mf) async {
    final u = _user;
    if (u == null) return;
    _avatarProgress = 0;
    _error = null;
    notifyListeners();
    try {
      await repo.api.uploadAvatar(userId: u.id, avatarData: mf);
      _avatarProgress = 1.0;
      notifyListeners();
      await load(userId: u.id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> uploadBackground(MultipartFile mf) async {
    final u = _user;
    if (u == null) return;
    _backgroundProgress = 0;
    _error = null;
    notifyListeners();
    try {
      await repo.api.uploadProfileBackground(userId: u.id, backgroundData: mf);
      _backgroundProgress = 1.0;
      notifyListeners();
      await load(userId: u.id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
