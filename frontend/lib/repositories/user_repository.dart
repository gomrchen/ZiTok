import '../services/user_service.dart';
import '../models/user_models.dart';

class UserRepository {
  final UserService api;
  const UserRepository({required this.api});

  Future<UserInfo> info({int? uid, String? userName}) async {
    final resp = await api.info(uid: uid, userName: userName);
    final data = resp.data as Map<String, dynamic>? ?? {};
    final info = (data['info'] as Map<String, dynamic>? ?? data);
    return UserInfo.fromJson(info);
  }
}