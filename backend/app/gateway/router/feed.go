package router

import (
	"context"
	"strconv"

	"github.com/cloudwego/hertz/pkg/app"
	"github.com/cloudwego/hertz/pkg/app/server"
	"github.com/yxrxy/videoHub/app/gateway/mw"
	"github.com/yxrxy/videoHub/app/gateway/pack"
	"github.com/yxrxy/videoHub/app/gateway/rpc"
	"github.com/yxrxy/videoHub/kitex_gen/social"
	"github.com/yxrxy/videoHub/kitex_gen/video"
	metainfoContext "github.com/yxrxy/videoHub/pkg/base/context"
)

// RegisterFeedRoutes 关注流：聚合好友作品。无关注时返回空列表（兼容旧客户端 /feed/follow）。
func RegisterFeedRoutes(h *server.Hertz) {
	api := h.Group("/api/v1", mw.Auth())
	api.GET("/feed/follow", followFeed)
}

func followFeed(ctx context.Context, c *app.RequestContext) {
	uid, err := metainfoContext.GetUserID(ctx)
	if err != nil || uid <= 0 {
		pack.RespData(c, []any{})
		return
	}
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	size, _ := strconv.Atoi(c.DefaultQuery("size", "10"))
	if page < 1 {
		page = 1
	}
	if size < 1 || size > 50 {
		size = 10
	}

	page32, size32 := int32(1), int32(50)
	friends, _, ferr := rpc.GetUserFriendsRPC(ctx, &social.GetUserFriendsRequest{
		UserId: uid,
		Page:   &page32,
		Size:   &size32,
	})
	if ferr != nil || len(friends) == 0 {
		pack.RespData(c, []any{})
		return
	}

	out := make([]any, 0, size)
	perUser := 3
	if size < perUser {
		perUser = size
	}
	for _, f := range friends {
		if f == nil {
			continue
		}
		friendID := f.FriendId
		if friendID == uid {
			friendID = f.UserId
		}
		if friendID <= 0 || friendID == uid {
			continue
		}
		list, lerr := rpc.GetVideoListRPC(ctx, &video.VideoListRequest{
			UserId: friendID,
			Page:   int64(page),
			Size:   int32(perUser),
		})
		if lerr != nil || list == nil {
			continue
		}
		for _, item := range list {
			out = append(out, item)
			if len(out) >= size {
				pack.RespData(c, out)
				return
			}
		}
	}
	pack.RespData(c, out)
}
