import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user_models.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../repositories/user_repository.dart';
import '../services/user_service.dart';
import 'package:dio/dio.dart';

class ProfileProvider extends ChangeNotifier {
  final UserRepository repo;
  User? _user;
  bool _loading = false;
  String? _error;
  double _avatarProgress = 0;
  double _backgroundProgress = 0;
  Timer? _debounce;

  ProfileProvider({required this.repo});

  User? get user => _user;
  bool get loading => _loading;
  String? get error => _error;
  double get avatarUploadProgress => _avatarProgress;
  double get backgroundUploadProgress => _backgroundProgress;

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
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

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
        box.put('username', updated.username);
        box.put('bio', updated.bio);
        box.put('avatar_url', updated.avatarUrl);
        box.put('background_url', updated.profileBackgroundImageUrl);
        box.put('gender', switch (updated.gender) { Gender.male => 1, Gender.female => 2, _ => 0 });
        box.put('birthday', updated.birthday);
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
}