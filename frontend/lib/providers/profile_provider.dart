import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_models.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../repositories/user_repository.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

import 'auth_provider.dart';

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
      return;
    }

    _loadingStats = true;
    _statsError = null;
    notifyListeners();

    try {
      final followersCount = await repo.getFollowersCount(userId: targetUserId);
      final followingsCount = await repo.getFollowingsCount(userId: targetUserId);

      _followersCount = followersCount;
      _followingsCount = followingsCount;
    } catch (e) {
      _statsError = e.toString();
      _followersCount = 0;
      _followingsCount = 0;
    } finally {
      _loadingStats = false;
      notifyListeners();
    }
  }

  Future<void> loadFromAuthProvider(BuildContext context) async {
    try {
      final authProvider = context.read<AuthProvider>();

      if (authProvider.user != null && authProvider.user!.id.isNotEmpty) {
        await load(userId: authProvider.user!.id);
      } else {
        await loadFromCache();
      }
    } catch (e) {
      _error = '加载用户数据失败: $e';
      notifyListeners();
    }
  }

  Future<void> load({String? userId}) async {
    String? targetUserId = userId;
    if (targetUserId == null) {
      final box = Hive.box('user_box');
      targetUserId = box.get('id') as String?;

      if (targetUserId == null) {
        final prefs = await SharedPreferences.getInstance();
        targetUserId = prefs.getString('auth_user_id');
      }
    }

    if (targetUserId == null || targetUserId.isEmpty) {
      _error = '无法获取用户ID，请先登录';
      _loading = false;
      notifyListeners();
      return;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await repo.info(userId: targetUserId);

      if (_user != null) {
        final box = Hive.box('user_box');
        await box.put('id', _user!.id);
        await box.put('username', _user!.username);
        await box.put('avatar_url', _user!.avatarUrl);
        await box.put('background_url', _user!.profileBackgroundImageUrl);
        await box.put('bio', _user!.bio);
        await box.put('gender', switch (_user!.gender) {
          Gender.male => 1,
          Gender.female => 2,
          _ => 0
        });
        await box.put('birthday', _user!.birthday);

        unawaited(loadUserStats(userId: _user!.id));
      } else {
        _error = '用户数据为空';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final String? cachedUserId = prefs.getString('auth_user_id');

    if (cachedUserId != null && cachedUserId.isNotEmpty) {
      await load(userId: cachedUserId);
    } else {
      final box = Hive.box('user_box');
      final String? hiveUserId = box.get('id') as String?;

      if (hiveUserId != null && hiveUserId.isNotEmpty) {
        await load(userId: hiveUserId);
      } else {
        _error = '无法获取用户ID，请先登录';
        notifyListeners();
      }
    }
  }

  void updateLocal(User next) {
    _user = next;
    notifyListeners();
  }

  void debounceUpdateInfo({
    String? username,
    String? signature,
    int? gender,
    String? birthday,
    String? avatarUrl,
    String? backgroundUrl,
  }) {
    final u = _user;
    if (u == null) return;

    final Gender gEnum = switch (gender) {
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
        await box.put('username', updated.username);
        await box.put('bio', updated.bio);
        await box.put('avatar_url', updated.avatarUrl);
        await box.put('background_url', updated.profileBackgroundImageUrl);
        await box.put('gender', switch (updated.gender) {
          Gender.male => 1,
          Gender.female => 2,
          _ => 0
        });
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
