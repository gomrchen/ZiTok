import 'package:flutter/foundation.dart';
import '../repositories/auth_repository.dart';
import '../models/user_models.dart';
import '../services/user_session.dart';

/// 认证 Provider：维护登录态与用户数据
class AuthProvider extends ChangeNotifier {
  final AuthRepository authRepository;
  final UserSession userSession;

  bool _loading = false;
  String? _error;
  User? _registeredUser;

  AuthProvider({
    required this.authRepository,
    required this.userSession,
  });

  bool get isAuthenticated => userSession.isLoggedIn;
  bool get isRegistered => _registeredUser != null;
  bool get loading => _loading;
  String? get error => _error;

  /// 当前用户信息
  User? get user => userSession.user;

  /// 当前用户 ID（推荐通过 UserSession 获取）
  String? get userId => userSession.userId;

  Future<void> login(String username, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final user = await authRepository.login(
        username: username,
        password: password,
      );
      // 用户信息已在 authRepository.login 中通过 UserSession 设置
      userSession.updateUser(user);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> register(
    String username,
    String email,
    String password,
    String verificationCode,
  ) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _registeredUser = await authRepository.register(
        username: username,
        email: email,
        password: password,
        verificationCode: verificationCode,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> changePassword(
      String email, String code, String newPassword) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await authRepository.changePassword(
        email: email,
        code: code,
        newPassword: newPassword,
      );
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> sendVerificationCode(String email) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await authRepository.sendVerificationCode(email: email);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _loading = true;
    _error = null;
    try {
      await authRepository.logout();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
