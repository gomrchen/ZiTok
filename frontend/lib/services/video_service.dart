import 'package:dio/dio.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// 上传进度回调类型
typedef UploadProgressCallback = void Function(int sent, int total);

class VideoService {
  final Dio dio;
  VideoService(this.dio);

  Future<Response> list({String? userId, int page = 1, int size = 20}) {
    final String uidOrTs = (userId != null && userId.isNotEmpty)
        ? userId
        : DateTime.now().millisecondsSinceEpoch.toString();
    return dio.get('/video/list', queryParameters: {
      'user_id': uidOrTs,
      'page': page,
      'size': size,
    });
  }

  Future<Response> hot({int pageSize = 20, int pageNum = 1}) {
    return dio.get('/video/hot', queryParameters: {
      'page_size': pageSize,
      'page_num': pageNum,
    });
  }

  Future<Response> detail({required String videoId, int page = 1, int size = 10}) {
    return dio.get('/video/$videoId', queryParameters: {
      'page': page,
      'size': size,
    });
  }

  Future<Response> like({required String videoId}) {
    return dio.post('/video/$videoId/like');
  }

  Future<Response> visit({required String videoId}) {
    return dio.post('/video/$videoId/visit');
  }

  /// 发布视频
  ///
  /// [filePath] 本地视频文件路径
  /// [title] 视频标题
  /// [description] 视频描述
  /// [userId] 用户ID
  /// [onProgress] 上传进度回调
  Future<Response> publish({
    required String filePath,
    required String title,
    required String description,
    required String userId,
    UploadProgressCallback? onProgress,
  }) async {
    // 参数校验
    if (title.trim().isEmpty) {
      throw ArgumentError('视频标题不能为空');
    }
    if (userId.trim().isEmpty) {
      throw ArgumentError('用户ID不能为空');
    }

    // 构建文件上传
    final MultipartFile videoFile;
    if (kIsWeb) {
      // Web平台：filePath实际是文件bytes的base64或blob URL，需要特殊处理
      // 暂时抛出不支持异常，后续可扩展支持
      throw UnsupportedError('Web平台暂不支持视频上传，请使用移动端或桌面端');
    } else {
      // 移动端/桌面端：从文件路径读取
      final file = File(filePath);
      if (!await file.exists()) {
        throw ArgumentError('视频文件不存在: $filePath');
      }
      final fileName = filePath.split(Platform.pathSeparator).last;
      videoFile = await MultipartFile.fromFile(
        filePath,
        filename: fileName,
      );
    }

    final form = FormData.fromMap({
      'video_data': videoFile,
      'title': title.trim(),
      'description': description.trim(),
      'user_id': userId,
    });

    return dio.post(
      '/video/publish',
      data: form,
      onSendProgress: onProgress,
      options: Options(
        sendTimeout: const Duration(minutes: 30),
        receiveTimeout: const Duration(minutes: 5),
      ),
    );
  }

  Future<Response> search({required String keywords, int pageSize = 10, int pageNum = 1}) {
    return dio.post('/video/search', data: {
      'keywords': keywords,
      'page_size': pageSize,
      'page_num': pageNum,
    });
  }

  /// 获取关注用户发布的视频
  ///
  /// [userId] 当前用户ID（用于获取其关注列表的视频）
  /// [page] 页码
  /// [size] 每页数量
  Future<Response> followFeed({required String userId, int page = 1, int size = 20}) {
    return dio.get('/feed/follow', queryParameters: {
      'user_id': userId,
      'page': page,
      'size': size,
    });
  }

  Future<Response> delete({required String videoId, String? userId}) {
    return dio.delete('/video/1', queryParameters: {
      'video_id': videoId,
      if (userId != null) 'user_id': userId,
    });
  }
}
