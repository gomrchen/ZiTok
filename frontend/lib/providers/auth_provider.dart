import 'package:flutter/foundation.dart';
import '../repositories/auth_repository.dart';
import '../models/user_models.dart';

/// 认证 Provider：维护登录态与用户数据
class AuthProvider extends ChangeNotifier {
  final AuthRepository authRepository;

  bool _loading = false;
  String? _error;
  User? _user;
 User?_registeredUser;

  AuthProvider({required this.authRepository});

  bool get isAuthenticated => _user != null;
  bool get isRegistered => _registeredUser != null;
  bool get loading => _loading;
  String? get error => _error;
  User? get user => _user;
  
  Future<void> login(String username, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await authRepository.login(
        username: username,
        password: password,
      );
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

//修改密码
  Future<void> changePassword(String email,String code, String newPassword) async {
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
  /// 发送验证码到邮箱
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
  /// 登出，清除用户状态
  Future<void> logout() async {
    _loading = true;
    _error = null;
    try {
      await authRepository.logout();
      // 清除本地用户状态
      _user = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}

