import '../services/notes_service.dart';
import '../models/notes_models.dart';

class NotesRepository {
  final NotesService api;
  const NotesRepository({required this.api});

  Future<NoteListResp> list(String videoId) async {
    final resp = await api.list(videoId: videoId);
    final data = resp.data as Map<String, dynamic>? ?? {};
    return NoteListResp.fromJson(data);
  }

  Future<NoteItem> create({required String videoId, required String title, required String content, required int seconds}) async {
    final resp = await api.create(videoId: videoId, title: title, content: content, seconds: seconds);
    final data = resp.data as Map<String, dynamic>? ?? {};
    return NoteItem.fromJson(data['item'] as Map<String, dynamic>);
  }

  Future<void> delete(String noteId) async {
    await api.delete(noteId: noteId);
  }
}