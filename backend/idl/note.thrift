namespace go note

include "user.thrift"

struct BaseResp {
    1: required i64 code,
    2: optional string msg,
}

struct Note {
    1: required i64 id,
    2: required i64 video_id,
    3: required i64 user_id,
    4: required string content,
    5: required i64 type,  // 1: 附件笔记(attachment), 2: 用户笔记(user)
    6: required string created_at,
    7: required string updated_at,
}

struct CreateNoteRequest {
    1: required i64 video_id,
    2: required string content,
    3: required i64 type,
    4: required string token,
}

struct CreateNoteResponse {
    1: required BaseResp base,
    2: optional Note note,
}

struct GetNoteRequest {
    1: required i64 note_id,
    2: required string token,
}

struct GetNoteResponse {
    1: required BaseResp base,
    2: optional Note note,
}

struct GetNotesByVideoRequest {
    1: required i64 video_id,
    2: required string token,
}

struct GetNotesByVideoResponse {
    1: required BaseResp base,
    2: required list<Note> notes,
}

struct GetNotesByUserRequest {
    1: required i64 user_id,
    2: required string token,
}

struct GetNotesByUserResponse {
    1: required BaseResp base,
    2: required list<Note> notes,
}

struct UpdateNoteRequest {
    1: required i64 note_id,
    2: required string content,
    3: required string token,
}

struct UpdateNoteResponse {
    1: required BaseResp base,
}

struct DeleteNoteRequest {
    1: required i64 note_id,
    2: required string token,
}

struct DeleteNoteResponse {
    1: required BaseResp base,
}

service NoteService {
    CreateNoteResponse CreateNote(1: CreateNoteRequest req)
    GetNoteResponse GetNote(1: GetNoteRequest req)
    GetNotesByVideoResponse GetNotesByVideo(1: GetNotesByVideoRequest req)
    GetNotesByUserResponse GetNotesByUser(1: GetNotesByUserRequest req)
    UpdateNoteResponse UpdateNote(1: UpdateNoteRequest req)
    DeleteNoteResponse DeleteNote(1: DeleteNoteRequest req)
}

