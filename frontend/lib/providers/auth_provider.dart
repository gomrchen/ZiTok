import 'package:flutter/foundation.dart';
import '../repositories/auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository authRepository;

  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _user;

  AuthProvider({required this.authRepository});

  bool get isAuthenticated => authRepository.accessToken != null && authRepository.accessToken!.isNotEmpty;
  bool get loading => _loading;
  String? get error => _error;
  Map<String, dynamic>? get user => _user;

  Future<void> login(String phone, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await authRepository.login(phone: phone, password: password);
      _user = await authRepository.profile();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> register(String phone, String otp, {String? password}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await authRepository.register(phone: phone, otp: otp, password: password);
      _user = await authRepository.profile();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}