import 'package:flutter/foundation.dart';
import '../repositories/auth_repository.dart';
import '../models/user_models.dart';

/// 认证 Provider：维护登录态与用户数据
class AuthProvider extends ChangeNotifier {
  final AuthRepository authRepository;

  bool _loading = false;
  String? _error;
  User? _user;

  AuthProvider({required this.authRepository});

  bool get isAuthenticated => _user != null;
  bool get loading => _loading;
  String? get error => _error;
  User? get user => _user;

  Future<void> login(String username, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await authRepository.login(username: username, password: password);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> register(String username, String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await authRepository.register(username: username, email: email, password: password);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
