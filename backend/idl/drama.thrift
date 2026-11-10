namespace go drama

include "model.thrift"

struct DramaInfo {
    1: required i64 id
    2: required string title
    3: required string cover_url
    4: required string description
    5: required string category
    6: required string tags
    7: required i32 total_episodes
    8: required i32 free_episode_count
    9: required i32 bundle_price
    10: required i8 status
    11: required i64 play_count
    12: required i64 like_count
}

struct EpisodeInfo {
    1: required i64 id
    2: required i64 drama_id
    3: required i32 episode_no
    4: required string title
    5: required string video_url
    6: required string cover_url
    7: required i64 duration
    8: required bool is_free
    9: required i32 unlock_price
    10: required i64 visit_count
    11: required i64 like_count
}

struct FeedItem {
    1: required DramaInfo drama
    2: required EpisodeInfo episode
    3: required bool locked
}

struct PlayInfo {
    1: required EpisodeInfo episode
    2: required DramaInfo drama
    3: required bool locked
    4: required i32 unlock_price
    5: required bool can_play
    6: optional string video_url
}

struct ListDramasRequest {
    1: required i32 page
    2: required i32 size
    3: optional string category
    4: optional i8 status
}

struct ListDramasResponse {
    1: required model.BaseResp Base
    2: required list<DramaInfo> list
    3: required i64 total
}

struct GetDramaDetailRequest {
    1: required i64 drama_id
    2: optional i64 user_id
}

struct GetDramaDetailResponse {
    1: required model.BaseResp Base
    2: required DramaInfo drama
    3: required list<EpisodeInfo> episodes
    4: required bool favorite
}

struct ListEpisodesRequest {
    1: required i64 drama_id
}

struct ListEpisodesResponse {
    1: required model.BaseResp Base
    2: required list<EpisodeInfo> list
}

struct GetFeedRequest {
    1: required i32 page
    2: required i32 size
    3: optional i64 user_id
}

struct GetFeedResponse {
    1: required model.BaseResp Base
    2: required list<FeedItem> list
}

struct GetPlayInfoRequest {
    1: required i64 episode_id
    2: optional i64 user_id
}

struct GetPlayInfoResponse {
    1: required model.BaseResp Base
    2: required PlayInfo info
}

struct ReportProgressRequest {
    1: required i64 user_id
    2: required i64 drama_id
    3: required i64 episode_id
    4: required i32 episode_no
    5: required i32 position_sec
}

struct ReportProgressResponse {
    1: required model.BaseResp Base
}

struct ContinueWatchingRequest {
    1: required i64 user_id
    2: optional i32 limit
}

struct ContinueItem {
    1: required i64 drama_id
    2: required i64 episode_id
    3: required i32 episode_no
    4: required i32 position_sec
    5: optional DramaInfo drama
    6: optional EpisodeInfo episode
}

struct ContinueWatchingResponse {
    1: required model.BaseResp Base
    2: required list<ContinueItem> list
}

struct FavoriteRequest {
    1: required i64 user_id
    2: required i64 drama_id
}

struct FavoriteResponse {
    1: required model.BaseResp Base
}

struct ListFavoritesRequest {
    1: required i64 user_id
}

struct ListFavoritesResponse {
    1: required model.BaseResp Base
    2: required list<DramaInfo> list
}

struct SearchDramasRequest {
    1: required string keyword
    2: required i32 page
    3: required i32 size
}

struct SearchDramasResponse {
    1: required model.BaseResp Base
    2: required list<DramaInfo> list
    3: required i64 total
}

struct CreateDramaRequest {
    1: required string title
    2: optional string cover_url
    3: optional string description
    4: optional string category
    5: optional string tags
    6: optional i32 free_episode_count
    7: optional i32 bundle_price
    8: optional i8 status
}

struct CreateDramaResponse {
    1: required model.BaseResp Base
    2: required DramaInfo drama
}

struct UpdateDramaRequest {
    1: required i64 drama_id
    2: optional string title
    3: optional string cover_url
    4: optional string description
    5: optional string category
    6: optional string tags
    7: optional i32 free_episode_count
    8: optional i32 bundle_price
    9: optional i8 status
}

struct UpdateDramaResponse {
    1: required model.BaseResp Base
    2: required DramaInfo drama
}

struct OfflineDramaRequest {
    1: required i64 drama_id
}

struct OfflineDramaResponse {
    1: required model.BaseResp Base
}

struct CreateEpisodeRequest {
    1: required i64 drama_id
    2: required i32 episode_no
    3: required string title
    4: required string video_url
    5: optional string cover_url
    6: optional bool is_free
    7: optional i32 unlock_price
    8: optional i64 duration
}

struct CreateEpisodeResponse {
    1: required model.BaseResp Base
    2: required EpisodeInfo episode
}

struct UpdateEpisodeRequest {
    1: required i64 episode_id
    2: optional string title
    3: optional string video_url
    4: optional string cover_url
    5: optional bool is_free
    6: optional i32 unlock_price
    7: optional i32 episode_no
}

struct UpdateEpisodeResponse {
    1: required model.BaseResp Base
    2: required EpisodeInfo episode
}

service DramaService {
    ListDramasResponse ListDramas(1: ListDramasRequest req)
    GetDramaDetailResponse GetDramaDetail(1: GetDramaDetailRequest req)
    ListEpisodesResponse ListEpisodes(1: ListEpisodesRequest req)
    GetFeedResponse GetFeed(1: GetFeedRequest req)
    GetPlayInfoResponse GetPlayInfo(1: GetPlayInfoRequest req)
    ReportProgressResponse ReportProgress(1: ReportProgressRequest req)
    ContinueWatchingResponse ContinueWatching(1: ContinueWatchingRequest req)
    FavoriteResponse Favorite(1: FavoriteRequest req)
    FavoriteResponse Unfavorite(1: FavoriteRequest req)
    ListFavoritesResponse ListFavorites(1: ListFavoritesRequest req)
    SearchDramasResponse SearchDramas(1: SearchDramasRequest req)
    CreateDramaResponse CreateDrama(1: CreateDramaRequest req)
    UpdateDramaResponse UpdateDrama(1: UpdateDramaRequest req)
    OfflineDramaResponse OfflineDrama(1: OfflineDramaRequest req)
    CreateEpisodeResponse CreateEpisode(1: CreateEpisodeRequest req)
    UpdateEpisodeResponse UpdateEpisode(1: UpdateEpisodeRequest req)
}
