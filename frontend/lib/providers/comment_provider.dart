import 'package:flutter/material.dart';
import '../models/comment.dart'; // 假设 Comment 模型在 models/comment.dart
import '../repositories/comment_repository.dart';

/// 状态管理层，负责管理评论相关的状态，并向UI层提供数据。
class CommentProvider with ChangeNotifier {
  final CommentRepository _repo;

  // 通过构造函数注入 CommentRepository
  CommentProvider({required CommentRepository repo}) : _repo = repo;

  // 用于存储与特定视频ID关联的评论列表
  final Map<String, List<CommentItem>> _commentsMap = {};
  Map<String, List<CommentItem>> get commentsMap => _commentsMap;

  // 用于跟踪每个视频评论列表的加载状态
  final Map<String, bool> _loadingStatus = {};
  Map<String, bool> get loadingStatus => _loadingStatus;

  /// 获取或刷新指定视频的评论列表
  Future<void> fetchComments(String videoId) async {
    // 如果当前正在加载此视频的评论，则直接返回，防止重复请求
    if (_loadingStatus[videoId] == true) {
      return;
    }

    // 1. 设置加载状态为 true，并通知UI更新（例如显示加载指示器）
    _loadingStatus[videoId] = true;
    notifyListeners();

    // 2. 调用 Repository 层获取数据
    final comments = await _repo.getCommentList(videoId: videoId);

    // 3. 将获取到的数据存入 Map 中
    _commentsMap[videoId] = comments;
    print('Fetched comments for videoId: $videoId');
    print(comments);
    // 4. 加载完成，设置加载状态为 false，并再次通知UI更新以显示数据
    _loadingStatus[videoId] = false;
    notifyListeners();
  }

  /// 向指定视频添加一条新评论（采用“请求-刷新”模式）
  ///
  /// [videoId] 是当前视频的ID.
  /// [content] 是评论的内容.
  /// [parentId] 是可选的，如果这是一个回复，则为被回复评论的ID.
  /// 返回一个 Future<bool>，true表示成功，false表示失败。
  Future<bool> addComment({
    required String videoId,
    required String content,
    String? parentId,
  }) async {
    try {
      // 1. --- 调用API，与服务器同步 ---
      // 从 'v_123' 格式的 videoId 中解析出 int
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
      if (parsedVideoId == null) {
        print('添加评论失败: 无效的videoId格式');
        return false;
      }

      // 将 String? 类型的 parentId 解析为 int
      final int parsedParentId = int.tryParse(parentId ?? '-1') ?? -1;

      // 调用仓库层的方法将评论发送到后端
      await _repo.addComment(
        videoId: parsedVideoId,
        parentId: parsedParentId,
        content: content,
      );

      // 2. --- 成功后，重新获取整个评论列表 ---
      // 这将自动更新UI并保证数据是最新且完全正确的
      await fetchComments(videoId);

      print('评论添加成功，并已刷新列表。');
      return true; // 表示成功

    } catch (e) {
      // 3. --- API调用失败，打印错误 ---
      print('添加评论失败: $e');
      // 在这种模式下，因为我们没有预先修改UI，所以失败时什么都不用做。
      // UI上根本没有发生过变化。
      return false; // 表示失败
    }
  }
  /// 删除指定视频的评论（采用“请求-刷新”模式）
  ///
  /// [videoId] 是当前视频的ID.
  /// [commentId] 是要删除的评论的ID.
  /// 返回一个 Future<void>，表示操作完成。
  Future<void> deleteCommentAndChildren({
    required String videoId,
    required CommentItem commentToDelete,
  }) async {

    // 1. 收集父评论ID
    final List<String> idsToDelete = [commentToDelete.id];

    // 2. 收集所有直接子评论的ID
    for (var reply in commentToDelete.replies) {
      idsToDelete.add(reply.id);
    }

    // 如果一个子评论下还有孙子评论，这个方法将不会处理它们。
    // 这符合“只通过 CommentItem.List<CommentItem>”的要求。

    try {
      // 3. 并行调用删除接口，删除所有收集到的ID
      await Future.wait(idsToDelete.map(
            (id) => _repo.deleteComment(videoId: videoId, commentId: id),
      ));

      // 4. 删除成功后，重新获取整个视频的评论列表以刷新UI
      await fetchComments(videoId);

    } catch (e) {
      print('删除评论失败: $e');
      notifyListeners();
      // 推荐做法：即使删除失败，也刷新一次列表以同步最新状态
      await fetchComments(videoId);
    }
  }

}
