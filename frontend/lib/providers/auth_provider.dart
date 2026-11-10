import 'package:flutter/foundation.dart';
import '../repositories/auth_repository.dart';
import '../models/user_models.dart';
import '../services/user_session.dart';
import '../utils/error_handler.dart';

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

  /// 是否可以尝试自动登录（有userId和refreshToken）
  bool get canAttemptAutoLogin => userSession.canAttemptAutoLogin;
  bool get isRegistered => _registeredUser != null;
  bool get loading => _loading;
  String? get error => _error;

  User? get user => userSession.user;
  String? get userId => userSession.userId;

  void setLocalError(String? message) {
    _error = message;
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  String _friendly(dynamic e) {
    if (e is AuthException) return AuthException.friendlyMessage(e.message);
    return ErrorHandler.getErrorMessage(e, defaultMessage: '操作失败，请稍后重试');
  }

  Future<void> login(String username, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final user = await authRepository.login(
        username: username,
        password: password,
      );
      userSession.updateUser(user);
    } catch (e) {
      _error = _friendly(e);
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
      _error = _friendly(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> changePassword(
    String email,
    String code,
    String newPassword,
  ) async {
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
      _error = _friendly(e);
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
      _error = _friendly(e);
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
      _error = _friendly(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
