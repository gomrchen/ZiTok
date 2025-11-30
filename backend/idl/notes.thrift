namespace go notes

include "model.thrift"

// 笔记模型
enum NoteStatus {
    NORMAL = 0,
    DELETED = 1,
}

// 创建笔记请求
struct CreateNoteRequest {
    1: required i64 user_id         // 用户ID（创建者）
    2: optional i64 video_id        // 视频ID（可选，关联视频）
    3: optional i64 related_user_id // 关联用户ID（可选，关联用户）
    4: required string title        // 笔记标题
    5: required string content      // 笔记内容
    6: optional i32 seconds         // 视频时间戳
}

// 创建笔记响应
struct CreateNoteResponse {
    1: required model.BaseResp Base // 基本响应信息
    2: optional i64 note_id         // 笔记ID
}

// 获取笔记列表请求
struct GetNotesRequest {
    1: required i64 video_id        // 视频ID
    2: optional i32 page            // 页码
    3: optional i32 size            // 每页大小
}

// 笔记信息
struct NoteInfo {
    1: required i64 id              // 笔记ID
    2: required i64 user_id         // 用户ID（创建者）
    3: optional i64 video_id        // 视频ID（可选，关联视频）
    4: optional i64 related_user_id // 关联用户ID（可选，关联用户）
    5: required string title        // 笔记标题
    6: required string content      // 笔记内容
    7: optional i32 seconds         // 视频时间戳
    8: required i64 created_at      // 创建时间
    9: optional i64 updated_at      // 更新时间
    10: optional model.User author  // 作者信息
    11: optional i32 like_count     // 点赞数
    12: optional i32 comment_count  // 评论数
    13: optional i32 favorite_count // 收藏数
    14: optional bool is_liked      // 当前用户是否点赞
    15: optional bool is_favorited  // 当前用户是否收藏
}

// 获取笔记列表响应
struct GetNotesResponse {
    1: required model.BaseResp Base      // 基本响应信息
    2: required list<NoteInfo> notes     // 笔记列表
    3: required i64 total                // 总数
}

// 删除笔记请求
struct DeleteNoteRequest {
    1: required i64 note_id         // 笔记ID
    2: required i64 user_id         // 用户ID
}

// 删除笔记响应
struct DeleteNoteResponse {
    1: required model.BaseResp Base // 基本响应信息
}

// 获取用户笔记列表请求
struct GetUserNotesRequest {
    1: required i64 user_id         // 用户ID
    2: optional i32 page            // 页码
    3: optional i32 size            // 每页大小
}

// 获取用户笔记列表响应
struct GetUserNotesResponse {
    1: required model.BaseResp Base      // 基本响应信息
    2: required list<NoteInfo> notes     // 笔记列表
    3: required i64 total                // 总数
}

// 点赞笔记请求
struct LikeNoteRequest {
    1: required i64 note_id         // 笔记ID
    2: required i64 user_id         // 用户ID
}

// 点赞笔记响应
struct LikeNoteResponse {
    1: required model.BaseResp Base // 基本响应信息
}

// 收藏笔记请求
struct FavoriteNoteRequest {
    1: required i64 note_id         // 笔记ID
    2: required i64 user_id         // 用户ID
}

// 收藏笔记响应
struct FavoriteNoteResponse {
    1: required model.BaseResp Base // 基本响应信息
}

// 笔记服务
service NotesService {
    // 创建笔记
    CreateNoteResponse CreateNote(1: CreateNoteRequest req)
    
    // 获取视频的笔记列表
    GetNotesResponse GetNotes(1: GetNotesRequest req)
    
    // 删除笔记
    DeleteNoteResponse DeleteNote(1: DeleteNoteRequest req)
    
    // 获取用户的笔记列表
    GetUserNotesResponse GetUserNotes(1: GetUserNotesRequest req)
    
    // 点赞笔记
    LikeNoteResponse LikeNote(1: LikeNoteRequest req)
    
    // 收藏笔记
    FavoriteNoteResponse FavoriteNote(1: FavoriteNoteRequest req)
}
