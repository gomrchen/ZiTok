import '../services/user_service.dart';
import '../models/user_models.dart';

/// 用户仓库：封装服务层并进行类型转换与错误处理
class UserRepository {
  final UserService api;
  const UserRepository({required this.api});

  Future<User> info({String? userId}) async {
    try {
      final resp = await api.info(userId: userId);
      final body = resp.data as Map<String, dynamic>? ?? {};

      if (body.isEmpty) {
        throw Exception('响应数据为空');
      }

      // 解析响应码
      final code = body['code'];
      final int statusCode;
      if (code is int) {
        statusCode = code;
      } else if (code is String) {
        statusCode = int.tryParse(code) ?? 0;
      } else {
        statusCode = 0;
      }

      // 检查响应状态
      if (statusCode != 10000 && statusCode != 200) {
        final errorMsg = body['message'] ?? '获取用户信息失败';
        throw Exception(errorMsg.toString());
      }

      // 解析用户数据
      final data = body['data'] as Map<String, dynamic>?;
      if (data == null || data.isEmpty) {
        throw Exception('用户数据为空或格式错误');
      }

      final user = User.fromJson(data);

      return user;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateInfo(UserUpdateRequest req) async {
    try {
      final resp = await api.updateInfo(req);
      final body = resp.data as Map<String, dynamic>? ?? {};

      // 解析响应码
      final code = body['code'];
      final int statusCode;
      if (code is int) {
        statusCode = code;
      } else if (code is String) {
        statusCode = int.tryParse(code) ?? 0;
      } else {
        statusCode = 0;
      }

      // 检查响应状态
      if (statusCode != 10000 && statusCode != 200) {
        final errorMsg = body['message'] ?? '更新用户信息失败';
        throw Exception(errorMsg.toString());
      }

    } catch (e) {
      rethrow;
    }
  }


  Future<int> getFollowingsCount({required String userId}) async {
    try {
      final resp = await api.getFollowings(userId: userId);
      final body = resp.data as Map<String, dynamic>? ?? {};

      // 解析响应码
      final code = body['code'];
      final int statusCode;
      if (code is int) {
        statusCode = code;
      } else if (code is String) {
        statusCode = int.tryParse(code) ?? 0;
      } else {
        statusCode = 0;
      }

      // 检查响应状态
      if (statusCode != 10000 && statusCode != 200) {
        final errorMsg = body['message'] ?? '获取关注数量失败';
        throw Exception(errorMsg.toString());
      }

      // 解析数据列表 - 根据你提供的响应格式
      final data = body['data'] as List<dynamic>?;
      final count = data?.length ?? 0;

      return count;
    } catch (e) {
      rethrow;
    }
  }

  Future<int> getFollowersCount({required String userId}) async {
    try {
      final resp = await api.getFollowers(userId: userId);
      final body = resp.data as Map<String, dynamic>? ?? {};

      // 解析响应码
      final code = body['code'];
      final int statusCode;
      if (code is int) {
        statusCode = code;
      } else if (code is String) {
        statusCode = int.tryParse(code) ?? 0;
      } else {
        statusCode = 0;
      }

      // 检查响应状态
      if (statusCode != 10000 && statusCode != 200) {
        final errorMsg = body['message'] ?? '获取粉丝数量失败';
        throw Exception(errorMsg.toString());
      }

      // 解析数据列表 - 根据你提供的响应格式
      final data = body['data'] as List<dynamic>?;
      final count = data?.length ?? 0;

      return count;
    } catch (e) {
      rethrow;
    }
  }
}
