namespace go api.notes

include "../notes.thrift"

// API 服务
service NotesAPI {
    // 笔记管理接口
    notes.CreateNoteResponse CreateNote(1: notes.CreateNoteRequest request) (api.post="/api/v1/notes/create")
    notes.GetNotesResponse GetNotes(1: notes.GetNotesRequest request) (api.get="/api/v1/notes/list")
    notes.DeleteNoteResponse DeleteNote(1: notes.DeleteNoteRequest request) (api.post="/api/v1/notes/delete")
    notes.GetUserNotesResponse GetUserNotes(1: notes.GetUserNotesRequest request) (api.get="/api/v1/notes/user/list")
    
    // 笔记互动接口
    notes.LikeNoteResponse LikeNote(1: notes.LikeNoteRequest request) (api.post="/api/v1/notes/like")
    notes.FavoriteNoteResponse FavoriteNote(1: notes.FavoriteNoteRequest request) (api.post="/api/v1/notes/favorite")
}
