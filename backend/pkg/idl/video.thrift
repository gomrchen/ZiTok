namespace go api.video

struct VideoInfo {
    1: optional string ID (go.tag="json:\"id,omitempry\"")
    2: optional string UID (go.tag="json:\"uid,omitempry\"")
    3: optional string VideoURL (go.tag="json:\"video_url,omitempry\"")
    4: optional string CoverURL (go.tag="json:\"cover_url,omitempry\"")
    5: optional string Intro (go.tag="json:\"intro,omitempry\"")
    6: optional string Title (go.tag="json:\"title,omitempry\"")
    7: optional i32 Starts (go.tag="json:\"starts,omitempry\"")
    8: optional i32 Likes (go.tag="json:\"likes,omitempry\"")
    9: optional i32 Views (go.tag="json:\"views,omitempry\"")
}

struct VideoFeedReq {
    2: optional i64 VID (go.tag="form:\"vid,required\"")
}

struct VideoFeedResp {
    1: optional binary Video (go.tag="json:\"vid,omitempry\"")
}


struct PublishVideoReq {
    1: optional string Intro (go.tag="form:\"intro,required\"")
    2: optional string Title (go.tag="form:\"title,required\"")
    3: optional binary Video
    4: optional binary cover
    5: optional i64 UID
    6: optional string VideoName
    7: optional string CoverName
}

struct PublishVideoResp {
    1: optional string VID 
}


struct GetVideoListReq {
    1: optional i64 UID
    2: optional i32 Pages (go.tag="form:\"pages,required\"")
    3: optional i8 Size (go.tag="form:\"size,required\"")
}

struct GetVideoListResp {
    1: optional i32 Count (go.tag="json:\"count,omitempty\"")
    2: optional list<VideoInfo> Items (go.tag="json:\"items,omitempry\"")
}


struct GetVideoPopularReq {
}

struct GetVideoPopularResp {
    1: optional i32 Count (go.tag="json:\"count,omitempty\"")
    2: optional list<VideoInfo> Items (go.tag="json:\"items,omitempry\"")
}

struct SearchVideoReq {
    1: optional string Content (go.tag="form:\"content,required\"")
    2: optional i32 Pages (go.tag="form:\"pages,required\"")
    3: optional i8 Size (go.tag="form:\"size,required\"")
}

struct SearchVideoResp {
    1: optional i32 Count (go.tag="json:\"count,omitempry\"")
    2: optional list<VideoInfo> items (go.tag="json:\"items,omitempry\"")
}

service VideoService {
    VideoFeedResp VideoFeed(1: VideoFeedReq req) (streaming.mode="server")
    PublishVideoResp PublishVideo(1: PublishVideoReq req)
    GetVideoListResp GetVideoList(1: GetVideoListReq req)
    GetVideoPopularResp GetVideoPopular(1: GetVideoPopularReq req)
    SearchVideoResp SearchVideo(1: SearchVideoReq req)
}
