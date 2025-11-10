import '../services/user_service.dart';
import '../models/user_models.dart';

class UserRepository {
  final UserService api;
  const UserRepository({required this.api});

  /// 获取用户信息
  Future<UserInfo> info({required String uid}) async {
    // 1. 直接调用 UserService 中的 info 方法
    final resp = await api.info(userId: uid);

    // 2. 解析响应数据
    // 首先，将整个响应体解析为一个Map
    final responseBody = resp.data as Map<String, dynamic>? ?? {};

    // 3. 【修改】从响应体中获取 `data` 字段，这才是包含用户信息的Map
    final userInfoData = responseBody['data'] as Map<String, dynamic>?;

    // 4. 如果 `data` 字段不存在或为null，则抛出错误
    if (userInfoData == null) {
      // 从响应中获取错误消息，如果不存在则提供一个默认消息
      final message = responseBody['message']?.toString() ?? 'User data is missing in the response.';
      throw Exception('Failed to get user info: $message');
    }
    print('userInfoData: $userInfoData');
    // 5. 使用包含用户信息的 `data` Map来创建UserInfo对象
    return UserInfo.fromJson(userInfoData);
  }
}
