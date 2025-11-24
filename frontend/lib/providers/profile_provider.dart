import 'dart:async';
import 'package:flutter/foundation.dart';
<<<<<<< HEAD
import 'package:shared_preferences/shared_preferences.dart';
=======
>>>>>>> aaa4da01b9747b50aad04275356db124e0cdca7d
import '../models/user_models.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../repositories/user_repository.dart';
import '../services/user_service.dart';
import 'package:dio/dio.dart';
<<<<<<< HEAD
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

import 'auth_provider.dart'; // 或者 'package:flutter/widgets.dart'
=======
>>>>>>> aaa4da01b9747b50aad04275356db124e0cdca7d

class ProfileProvider extends ChangeNotifier {
  final UserRepository repo;
  User? _user;
  bool _loading = false;
  String? _error;
  double _avatarProgress = 0;
  double _backgroundProgress = 0;
  Timer? _debounce;
<<<<<<< HEAD
=======

>>>>>>> aaa4da01b9747b50aad04275356db124e0cdca7d
  ProfileProvider({required this.repo});

  User? get user => _user;
  bool get loading => _loading;
  String? get error => _error;
  double get avatarUploadProgress => _avatarProgress;
  double get backgroundUploadProgress => _backgroundProgress;

<<<<<<< HEAD
  // 添加一个方法来从AuthProvider加载用户数据
  Future<void> loadFromAuthProvider(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();

    if (authProvider.user != null && authProvider.user!.id.isNotEmpty) {
      print("🔍 ProfileProvider: 从AuthProvider获取用户ID: ${authProvider.user!.id}");
      await load(userId: authProvider.user!.id);
    } else {
      print("⚠️ ProfileProvider: AuthProvider中没有用户数据，尝试从缓存加载");
      await loadFromCache();
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
        print('🔍 ProfileProvider: 从本地存储获取userId: $targetUserId');
      }
    }

    // 如果仍然为null，设置一个默认值或报错
    if (targetUserId == null || targetUserId.isEmpty) {
      if (kDebugMode) {
        print('⚠️ ProfileProvider: 无法获取用户ID，跳过加载');
      }
      _loading = false;
      notifyListeners();
      return;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    if (kDebugMode) {
      print('🔍 ProfileProvider: 开始加载用户数据，userId: $targetUserId');
    }

    try {
      _user = await repo.info(userId: targetUserId);

      if (kDebugMode) {
        print('✅ ProfileProvider: 成功加载用户数据: ${_user?.username}');
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

        if (kDebugMode) {
          print('💾 ProfileProvider: 用户数据已保存到本地存储');
        }
      } else {
        if (kDebugMode) {
          print('❌ ProfileProvider: 用户数据为空');
        }
      }
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('❌ ProfileProvider: 加载用户数据失败: $e');
      }
=======
  Future<void> load({String? userId}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await repo.info(userId: userId);
      if (_user != null) {
        final box = Hive.box('user_box');
        box.put('id', _user!.id);
        box.put('username', _user!.username);
        box.put('avatar_url', _user!.avatarUrl);
        box.put('background_url', _user!.profileBackgroundImageUrl);
        box.put('bio', _user!.bio);
        box.put('gender', switch (_user!.gender) { Gender.male => 1, Gender.female => 2, _ => 0 });
        box.put('birthday', _user!.birthday);
      }
    } catch (e) {
      _error = e.toString();
>>>>>>> aaa4da01b9747b50aad04275356db124e0cdca7d
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

<<<<<<< HEAD
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

=======
>>>>>>> aaa4da01b9747b50aad04275356db124e0cdca7d
  void updateLocal(User next) {
    _user = next;
    notifyListeners();
  }

  void debounceUpdateInfo({String? username, String? signature, int? gender, String? birthday, String? avatarUrl, String? backgroundUrl}) {
    final u = _user;
    if (u == null) return;
    final gEnum = switch (gender) {
      1 => Gender.male,
      2 => Gender.female,
      _ => Gender.unknown,
    };
    final updated = u.copyWith(
      username: username ?? u.username,
      bio: signature ?? u.bio,
      avatarUrl: avatarUrl ?? u.avatarUrl,
      profileBackgroundImageUrl: backgroundUrl ?? u.profileBackgroundImageUrl,
      gender: gender == null ? u.gender : gEnum,
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
<<<<<<< HEAD
        await box.put('username', updated.username);
        await box.put('bio', updated.bio);
        await box.put('avatar_url', updated.avatarUrl);
        await box.put('background_url', updated.profileBackgroundImageUrl);
        await box.put('gender', switch (updated.gender) { Gender.male => 1, Gender.female => 2, _ => 0 });
        await box.put('birthday', updated.birthday);
=======
        box.put('username', updated.username);
        box.put('bio', updated.bio);
        box.put('avatar_url', updated.avatarUrl);
        box.put('background_url', updated.profileBackgroundImageUrl);
        box.put('gender', switch (updated.gender) { Gender.male => 1, Gender.female => 2, _ => 0 });
        box.put('birthday', updated.birthday);
>>>>>>> aaa4da01b9747b50aad04275356db124e0cdca7d
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
<<<<<<< HEAD

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
=======
}
>>>>>>> aaa4da01b9747b50aad04275356db124e0cdca7d
