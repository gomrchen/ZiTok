package handler

import (
	"context"
	"strconv"

	"github.com/cloudwego/hertz/pkg/app"

	"github.com/mutezebra/tiktok/app/gateway/domain/model"
	"github.com/mutezebra/tiktok/app/gateway/interface/pack"
	"github.com/mutezebra/tiktok/app/gateway/interface/rpc"
	"github.com/mutezebra/tiktok/pkg/constants"
	"github.com/mutezebra/tiktok/pkg/kitex_gen/api/relation"
)

func FollowHandler() app.HandlerFunc {
	return func(ctx context.Context, c *app.RequestContext) {
		var req relation.FollowReq
		if err := c.BindAndValidate(&req); err != nil {
			pack.SendFailedResponse(c, pack.ReturnError(model.InvalidParamErrno, err))
			return
		}

		req.UID = new(int64)
		*req.UID, _ = strconv.ParseInt(string(c.GetHeader(constants.HeaderUserIdKey)), 10, 64)

		resp, err := rpc.Follow(ctx, &req)
		if err != nil {
			pack.SendFailedResponse(c, err)
			return
		}

		pack.SendResponse(c, resp)
	}
}

func FollowListHandler() app.HandlerFunc {
	return func(ctx context.Context, c *app.RequestContext) {
		var req relation.GetFollowListReq
		req.UID = new(int64)
		*req.UID, _ = strconv.ParseInt(string(c.GetHeader(constants.HeaderUserIdKey)), 10, 64)

		resp, err := rpc.GetFollowList(ctx, &req)
		if err != nil {
			pack.SendFailedResponse(c, err)
			return
		}

		pack.SendResponse(c, resp)
	}
}

func FansListHandler() app.HandlerFunc {
	return func(ctx context.Context, c *app.RequestContext) {
		var req relation.GetFansListReq
		req.UID = new(int64)
		*req.UID, _ = strconv.ParseInt(string(c.GetHeader(constants.HeaderUserIdKey)), 10, 64)

		resp, err := rpc.GetFansList(ctx, &req)
		if err != nil {
			pack.SendFailedResponse(c, err)
			return
		}

		pack.SendResponse(c, resp)
	}
}

func FriendsListHandler() app.HandlerFunc {
	return func(ctx context.Context, c *app.RequestContext) {
		var req relation.GetFriendsListReq
		req.UID = new(int64)
		*req.UID, _ = strconv.ParseInt(string(c.GetHeader(constants.HeaderUserIdKey)), 10, 64)

		resp, err := rpc.GetFriendsList(ctx, &req)
		if err != nil {
			pack.SendFailedResponse(c, err)
			return
		}

		pack.SendResponse(c, resp)
	}
}
