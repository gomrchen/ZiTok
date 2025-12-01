import '../services/notes_service.dart';
import '../models/notes_models.dart';

class NotesRepository {
  final NotesService api;
  const NotesRepository({required this.api});

  /// 获取视频关联的笔记列表
  Future<NoteListResp> getVideoNotes({
    required int videoId,
    int page = 1,
    int pageSize = 10,
  }) async {
    final resp = await api.getVideoNotes(
      videoId: videoId,
      page: page,
      pageSize: pageSize,
    );
    final data = resp.data as Map<String, dynamic>? ?? {};
    return NoteListResp.fromJson(data);
  }

  /// 获取用户的笔记列表
  Future<NoteListResp> getUserNotes({
    required int userId,
    int page = 1,
    int pageSize = 10,
  }) async {
    final resp = await api.getUserNotes(
      userId: userId,
      page: page,
      pageSize: pageSize,
    );
    final data = resp.data as Map<String, dynamic>? ?? {};
    return NoteListResp.fromJson(data);
  }

  /// 创建笔记
  Future<int?> create({
    required int videoId,
    required String title,
    required String content,
    List<String> imageUrls = const [],
    int seconds = 0,
  }) async {
    final resp = await api.create(
      videoId: videoId,
      title: title,
      content: content,
      imageUrls: imageUrls,
      seconds: seconds,
    );
    final data = resp.data as Map<String, dynamic>? ?? {};
    final noteData = data['data'] as Map<String, dynamic>?;
    return noteData?['note_id'] as int?;
  }

  /// 删除笔记
  Future<bool> delete(int noteId) async {
    final resp = await api.delete(noteId: noteId);
    final data = resp.data as Map<String, dynamic>? ?? {};
    return data['code']?.toString() == '10000';
  }

  /// 点赞/取消点赞笔记
  Future<bool> toggleLike(int noteId) async {
    final resp = await api.like(noteId: noteId);
    final data = resp.data as Map<String, dynamic>? ?? {};
    return data['code']?.toString() == '10000';
  }

  /// 收藏/取消收藏笔记
  Future<bool> toggleFavorite(int noteId) async {
    final resp = await api.favorite(noteId: noteId);
    final data = resp.data as Map<String, dynamic>? ?? {};
    return data['code']?.toString() == '10000';
  }
}