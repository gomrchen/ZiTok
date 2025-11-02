package rpc

import (
	"context"

	"github.com/mutezebra/tiktok/pkg/kitex_gen/api/relation"
)

func Follow(ctx context.Context, req *relation.FollowReq) (r *relation.FollowResp, err error) {
	r, err = RelationClient.Follow(ctx, req)
	return
}

func GetFollowList(ctx context.Context, req *relation.GetFollowListReq) (r *relation.GetFollowListResp, err error) {
	r, err = RelationClient.GetFollowList(ctx, req)
	return
}

func GetFansList(ctx context.Context, req *relation.GetFansListReq) (r *relation.GetFansListResp, err error) {
	r, err = RelationClient.GetFansList(ctx, req)
	return
}

func GetFriendsList(ctx context.Context, req *relation.GetFriendsListReq) (r *relation.GetFriendsListResp, err error) {
	r, err = RelationClient.GetFriendsList(ctx, req)
	return
}
