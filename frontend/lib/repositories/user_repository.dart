import '../services/user_service.dart';
import '../models/user_models.dart';

/// 用户仓库：封装服务层并进行类型转换与错误处理
class UserRepository {
  final UserService api;
  const UserRepository({required this.api});

  Future<User> info({String? userId}) async {
    try {
      print('🔍 UserRepository.info: 开始获取用户信息，userId: $userId');

      final resp = await api.info(userId: userId);
      final body = resp.data as Map<String, dynamic>? ?? {};

      print('📦 UserRepository.info: 原始响应: $body');

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

      print('📦 UserRepository: 原始用户数据: $data');

      final user = User.fromJson(data);
      print('✅ UserRepository: 解析后的用户: ${user.username}, id: ${user.id}');

      return user;
    } catch (e) {
      print('❌ UserRepository.info 错误: $e');
      rethrow;
    }
  }

  Future<void> updateInfo(UserUpdateRequest req) async {
    try {
      print('🔍 UserRepository.updateInfo: 开始更新用户信息: ${req.toQuery()}');

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

      print('✅ UserRepository.updateInfo: 更新成功');
    } catch (e) {
      print('❌ UserRepository.updateInfo 错误: $e');
      rethrow;
    }
  }


  Future<int> getFollowingsCount({required String userId}) async {
    try {
      print('🔍 UserRepository.getFollowingsCount: 开始获取关注数量，userId: $userId');

      final resp = await api.getFollowings(userId: userId);
      final body = resp.data as Map<String, dynamic>? ?? {};

      print('📦 UserRepository.getFollowingsCount: 原始响应: $body');

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

      print('✅ UserRepository.getFollowingsCount: 获取到关注数量: $count');
      return count;
    } catch (e) {
      print('❌ UserRepository.getFollowingsCount 错误: $e');
      rethrow;
    }
  }

  Future<int> getFollowersCount({required String userId}) async {
    try {
      print('🔍 UserRepository.getFollowersCount: 开始获取粉丝数量，userId: $userId');

      final resp = await api.getFollowers(userId: userId);
      final body = resp.data as Map<String, dynamic>? ?? {};

      print('📦 UserRepository.getFollowersCount: 原始响应: $body');

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

      print('✅ UserRepository.getFollowersCount: 获取到粉丝数量: $count');
      return count;
    } catch (e) {
      print('❌ UserRepository.getFollowersCount 错误: $e');
      rethrow;
    }
  }
}
