import 'package:dio/dio.dart';
import '../models/user_models.dart';
import '../models/video.dart';

/// 用户接口服务（对接真实 API）
class UserService {
  final Dio dio;
  UserService(this.dio);

  /// 注册
  Future<Response> register({required String username, required String email, required String password}) {
    return dio.post('/user/register', data: {
      'username': username,
      'email': email,
      'password': password,
    });
  }

  /// 登录
  Future<Response> login({required String username, required String password}) {
    return dio.post('/user/login', data: {
      'username': username,
      'password': password,
    });
  }

  /// 用户信息
  Future<Response> info({String? userId}) {
    return dio.get('/user/info', queryParameters: {
      if (userId != null) 'user_id': userId,
    });
  }

  /// 上传头像（multipart/form-data）
  Future<Response> uploadAvatar({required String userId, required MultipartFile avatarData}) {
    final form = FormData.fromMap({
      'avatar_data': avatarData,
      'user_id': userId,
    });
    return dio.post('/user/avatar', data: form);
  }

  /// 上传资料背景图（multipart/form-data）
  Future<Response> uploadProfileBackground({required String userId, required MultipartFile backgroundData}) {
    final form = FormData.fromMap({
      'background_data': backgroundData,
      'user_id': userId,
    });
    return dio.post('/user/background', data: form);
  }

  /// 更新基本资料
  Future<Response> updateInfo(UserUpdateRequest req) {
    return dio.put('/user/info', queryParameters: req.toQuery());
  }

  /// 修改密码
  Future<Response> updatePassword({required String email, required String oldPassword, required String newPassword}) {
    return dio.put('/user/password', data: {
      'email': email,
      'old_password': oldPassword,
      'new_password': newPassword,
    });
  }

  /// 获取关注列表
  Future<Response> getFollowings({required String userId}) {
    return dio.get('/social/friend/requests', queryParameters: {
      'user_id': userId,
      'type': 0, // type=0 查找我的关注
    });
  }

  /// 获取粉丝列表
  Future<Response> getFollowers({required String userId}) {
    return dio.get('/social/friend/requests', queryParameters: {
      'user_id': userId,
      'type': 1, // type=1 查找我的粉丝
    });
  }

  Future<List<Video>> getVideos({
    required String userId,
    int page = 1,
    int size = 999,
  }) async {
    try {
      final response = await dio.get('/video/list', queryParameters: {
        'user_id': userId,
        'page': page,
        'size': size,
      });

      // 解析响应数据
      if (response.data['code'] == '10000') {
        final List<dynamic> dataList = response.data['data'] ?? [];
        return dataList.map((item) => Video.fromJson(item)).toList();
      } else {
        throw Exception('获取视频列表失败: ${response.data['message']}');
      }
    } catch (e) {
      rethrow;
    }
  }



  /// 删除视频
  Future<Response> deleteVideo({required String videoId}) async {
    try {
      final response = await dio.delete('/video/$videoId');
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// 在 UserService 类中添加这个方法
  Future<Map<String, dynamic>> getComments({
    required String videoId,
    int page = 1,
    int size = 999,
  }) async {
    try {
      final response = await dio.get(
        '/video/comments',
        queryParameters: {
          'video_id': videoId,
          'page': page,
          'size': size,
        },
      );
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  /// 上传视频封面（multipart/form-data）- 仿照头像上传
  Future<Response> uploadVideoCover({
    required String videoId,
    required MultipartFile coverData,
  }) {
    // 将路径中的 {video_id} 替换为实际的 videoId
    final String path = '/video/$videoId/cover';
    final form = FormData.fromMap({
      'cover': coverData, // 字段名改为 'cover'
    });
    return dio.post(path, data: form);
  }

  /// 更新视频信息（包括封面）
  Future<Map<String, dynamic>> updateVideoInfo({
    required String videoId,
    String? title,
    String? description,
    List<String>? tags,
    String? coverUrl,
  }) async {
    try {
      final Map<String, dynamic> data = {};
      if (title != null) data['title'] = title;
      if (description != null) data['description'] = description;
      if (tags != null) data['tags'] = tags;
      if (coverUrl != null) data['cover_url'] = coverUrl;

      final response = await dio.put(
        '/video/$videoId',
        data: data,
      );

      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // 根据用户名搜索远程用户
  Future<Response> searchRemoteUsers(String keyword) {
    return dio.post('/user/username', data: {
      'username': keyword,
    });
  }
}
