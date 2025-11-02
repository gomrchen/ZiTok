namespace go api.relation


struct FollowReq {
    1: optional i64 FollowerID (go.tag="form:\"follower_id,required\"")
    3: optional i64 UID
}

struct FollowResp {
}

struct GetFollowListReq {
    1: optional i64 UID
}

struct GetFollowListResp {
    1: optional i32 Count (go.tag="json:\"count,omitempty\"")
    2: optional list<i64> items (go.tag="json:\"items,omitempty\"")
}

struct GetFansListReq {
    1: optional i64 UID
}

struct GetFansListResp {
    1: optional i32 Count (go.tag="json:\"count,omitempty\"")
    2: optional list<i64> items (go.tag="json:\"items,omitempty\"")
}

struct GetFriendsListReq {
    1: optional i64 UID
}

struct GetFriendsListResp {
    1: optional i32 Count (go.tag="json:\"count,omitempty\"")
    2: optional list<i64> items (go.tag="json:\"items,omitempty\"")
}

service RelationService {
    FollowResp Follow(1: FollowReq req)
    GetFollowListResp GetFollowList(1: GetFollowListReq req)
    GetFansListResp GetFansList(1: GetFansListReq req)
    GetFriendsListResp GetFriendsList(1: GetFriendsListReq req)
}