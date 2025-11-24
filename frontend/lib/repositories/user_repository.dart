import '../services/user_service.dart';
import '../models/user_models.dart';

/// 用户仓库：封装服务层并进行类型转换与错误处理
class UserRepository {
  final UserService api;
  const UserRepository({required this.api});

  Future<User> info({String? userId}) async {
    final resp = await api.info(userId: userId);
    final body = resp.data as Map<String, dynamic>? ?? {};
    final base = body['base'] as Map<String, dynamic>? ?? {};
    final topCode = body['code'];
    final code = (base['code'] is int
        ? base['code'] as int
        : topCode is int
            ? topCode
            : int.tryParse('${topCode}') ?? 0);
    if (code != 10000 && code != 200) {
      throw Exception((base['msg'] ?? body['message'] ?? '获取用户信息失败').toString());
    }
    final rawData = body['data'];
    final raw = (rawData is Map<String, dynamic>) ? rawData : body;
    return User.fromJson(raw);
  }

  Future<void> updateInfo(UserUpdateRequest req) async {
    final resp = await api.updateInfo(req);
    final body = resp.data as Map<String, dynamic>? ?? {};
    final base = body['base'] as Map<String, dynamic>? ?? {};
    final topCode = body['code'];
    final code = (base['code'] is int
        ? base['code'] as int
        : topCode is int
            ? topCode
            : int.tryParse('${topCode}') ?? 0);
    if (code != 10000 && code != 200) {
      throw Exception((base['msg'] ?? body['message'] ?? '更新用户信息失败').toString());
    }
  }
}
