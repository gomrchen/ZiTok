namespace go api.interaction

include "video.thrift"

struct CommentInfo {
    1: optional string ID (go.tag="json:\"id,omitempry\"")
    2: optional string UID (go.tag="json:\"uid,omitempry\"")
    3: optional string VID (go.tag="json:\"vid,omitempry\"")
    4: optional string RootID (go.tag="json:\"root_id,omitempry\"")
    5: optional string ReplyID (go.tag="json:\"reply_id,omitempry\"")
    6: optional string Content (go.tag="json:\"content,omitempry\"")
    7: optional i32 Likes (go.tag="json:\"likes,omitempry\"")
    8: optional string CreateAt (go.tag="json:\"create_id,omitempry\"")
}

struct LikeReq {
    1: optional i64 VideoID (go.tag="form:\"video_id\"")
    2: optional i64 CommentID (go.tag="form:\"comment_id\"")
    3: optional i64 UID
    4: optional i8 ActionType (go.tag="form:\"action_type,required\"")
}

struct LikeResp {
}

struct DislikeReq {
    1: optional i64 VideoID (go.tag="form:\"video_id\"")
    2: optional i64 CommentID (go.tag="form:\"comment_id\"")
    3: optional i64 UID
    4: optional i8 ActionType (go.tag="form:\"action_type,required\"")
}

struct DislikeResp {
}


struct LikeListReq {
    1: optional i64 UID
    2: optional i8 PageSize  (go.tag="form:\"page_size,required\"")
    3: optional i8 PageNum  (go.tag="form:\"page_num,required\"")
}


struct LikeListResp {
    1: optional i32 Count (go.tag="json:\"count,omitempty\"")
    2: optional list<video.VideoInfo> items  (go.tag="json:\"items,omitempty\"")
}

struct CommentReq {
    1: optional i64 VideoID (go.tag="form:\"video_id,required\"")
    2: optional i64 CommentID (go.tag="form:\"comment_id\"")
    3: optional i64 UID
    4: optional string content (go.tag="form:\"content,required\"")
}

struct CommentResp {
}

struct CommentListReq {
    1: optional i64 VideoID (go.tag="form:\"video_id\"")
    2: optional i64 CommentID (go.tag="form:\"comment_id\"")
    3: optional i8 PageSize  (go.tag="form:\"page_size,required\"")
    4: optional i8 PageNum  (go.tag="form:\"page_num,required\"")
}

struct CommentListResp {
    1: optional i32 Count (go.tag="json:\"count,omitempry\"")
    2: optional list<CommentInfo> Items (go.tag="json:\"items,omitempry\"")
}

struct DeleteCommentReq {
    1: optional i64 UID
    2: optional i64 CommentID (go.tag="form:\"comment_id,required\"")
}

struct DeleteCommentResp {
    1: optional i64 UID
    2: optional i64 CommentID (go.tag="form:\"comment_id,required\"")
}


service InteractionService {
    LikeResp Like(1: LikeReq req)
    DislikeResp Dislike(1: DislikeReq req)
    LikeListResp LikeList(1: LikeListReq req)
    CommentResp Comment(1: CommentReq req)
    CommentListResp CommentList(1: CommentListReq req)
    DeleteCommentResp DeleteComment(1: DeleteCommentReq req)
}
