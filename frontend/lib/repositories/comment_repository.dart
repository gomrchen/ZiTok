import 'package:dio/dio.dart';
import 'package:zitok/providers/user_provider.dart';
import 'package:zitok/repositories/user_repository.dart';
import '../models/comment.dart'; // 引入您项目中的 comment.dart
import '../services/comment_service.dart'; // 引入 CommentService

/// 数据仓库层 (Repository)
///
/// 职责:
/// 1. 调用数据源 (CommentService) 来获取原始数据。
/// 2. 处理网络响应 (Response)，包括成功和失败的情况。
/// 3. 将原始的JSON数据转换为应用程序内部使用的模型对象 (Comment)。
class CommentRepository {
  final CommentService _api;
  final UserProvider _userProvider; // 【新增】持有 UserProvider 的实例

  // 【修改】通过构造函数注入 CommentService 和 UserProvider
  CommentRepository({
    required CommentService api,
    required UserProvider userProvider, // 【新增】
  })  : _api = api,
        _userProvider = userProvider; // 【新增】

  /// 获取指定视频的评论列表
  ///
  /// [videoId]: 视频的唯一标识符 (类型为 int，以匹配 Provider)。
  ///
  /// 返回一个 `Future<List<Comment>>`。
  Future<List<CommentItem>> getCommentList({
    required String videoId,
    int page = 1,
    int size = 20,
  }) async {
    try {
      // 1. 调用 CommentService 层，发起网络请求
      //    由于 Service 层需要 int 类型的 videoId，在这里进行转换。
      int? parsedVideoId;
      if (videoId.startsWith('v_')) {
        // 1. 如果字符串以 'v_' 开头，先截取掉前缀 'v_' (前2个字符)
        final String numberPart = videoId.substring(2);
        // 2. 然后对数字部分进行解析
        parsedVideoId = int.tryParse(numberPart);
      } else {
        // 如果不以 'v_' 开头，就按原来的方式尝试直接解析
        // (这可以兼容那些可能就是纯数字字符串的 videoId)
        parsedVideoId = int.tryParse(videoId);
      }
      final response = await _api.commentList(
        videoId: parsedVideoId ?? 0,
        pages: page,
        size: size,
      );

      // 1. 确认 response.data 是一个 Map
      if (response.data is Map<String, dynamic>) {
        final Map<String, dynamic> responseMap = response.data;
        final dynamic dataField = responseMap['data'];

        if (dataField is List) {
          // --- 核心逻辑：适配 String 类型的 ID 和 ParentID ---

          // 步骤 1: 将所有评论解析成对象
          final List<CommentItem> allComments = dataField
              .map((json) => CommentItem.fromJson(json as Map<String, dynamic>))
              .toList();
          if (allComments.isEmpty) {
            return [];
          }
          // 【新增】根据 authorId 获取并填充用户信息
          // 1. 收集所有不重复的用户ID
          final Set<String> userIds = allComments.map((c) => c.authorId).toSet();
          userIds.removeWhere((id) => id.isEmpty); // 移除空ID
          // 2. 并行获取所有用户信息
          final userFutures = userIds.map((id) => _userProvider.getUserInfo( id));
          final userInfos = await Future.wait(userFutures);
          // 3. 创建一个用户信息的Map，方便快速查找
          final userInfoMap = {for (var user in userInfos) user?.id: user};

          // 4. 遍历所有评论，更新作者姓名和头像
          for (var comment in allComments) {
            final userInfo = userInfoMap[comment.authorId];
            if (userInfo != null) {
              comment.author = userInfo.userName;
              comment.avatar = userInfo.avatar!;
            }
          }

          // Map 的键类型改为 String
          final Map<String, CommentItem> commentMap = {
            for (var comment in allComments) comment.id: comment
          };

          // 步骤 3: 遍历所有评论，将子孙评论全部添加到对应的根评论中
          final List<CommentItem> rootComments = [];
          for (var comment in allComments) {
            // 【修正 2】: 根评论的判断条件改为对字符串 '-1' 的判断
            if (comment.parentId == '-1') {
              rootComments.add(comment);
            } else {
              // 这是一个子评论或孙子评论，我们需要找到它的顶级根评论
              CommentItem? current = comment;
              CommentItem? rootComment;
              //获取父评论
              current.parent=commentMap[current.parentId];
              // 通过循环向上查找，直到找到根
              // 【修正 3】: 循环条件也改为对字符串 '-1' 的判断
              while (current != null && current.parentId != '-1' && current.parentId.isNotEmpty) {
                // 使用 String 类型的 parentId 从 Map 中查找
                current = commentMap[current.parentId];
              }
              // 此时 'current' 就是这个评论链的根评论
              rootComment = current;

              if (rootComment != null) {
                // 将当前评论添加到根评论的replies中
                rootComment.replies.add(comment);
              }
            }
          }

          // 步骤 4: 返回只包含根评论的列表
          return rootComments;
        }
      }
      // 如果以上任何一个检查失败，说明响应格式不符合预期
      print('Comment API response format is incorrect for videoId: $videoId. Response: ${response.data}');
      return [];
    } on DioException catch (e) {
      // 捕获并处理网络请求相关的异常
      print('Failed to get comment list for videoId: $videoId. Error: $e');
      return []; // 发生错误时返回空列表
    } catch (e) {
      // 捕获其他所有可能的异常
      print('An unknown error occurred while parsing comments for videoId: $videoId. Error: $e');
      return [];
    }
  }

  Future<void> addComment({required int videoId, required int parentId, required String content}) async {
    try {
      await _api.addComment(videoId: videoId, parentId: parentId, content: content);
      print('Comment added successfully.');
    } on DioException catch (e) {
      print('Failed to add comment. Error: $e');
    } catch (e) {
      print('An unknown error occurred while adding comment. Error: $e');
    }
  }
  Future<void> deleteComment({required String videoId,required String commentId}) async {
    String? parsedVideoId;
    if (videoId.startsWith('v_')) {
      // 1. 如果字符串以 'v_' 开头，先截取掉前缀 'v_' (前2个字符)
      parsedVideoId = videoId.substring(2);

    }
    try {
      await _api.deleteComment(videoId: parsedVideoId??'', commentId: commentId);
      print('Comment deleted successfully.');
    } on DioException catch (e) {
      print('Failed to delete comment. Error: $e');
    } catch (e) {
      print('An unknown error occurred while deleting comment. Error: $e');
    }
  }
}
