package router

import (
	"context"
	"strconv"

	"github.com/cloudwego/hertz/pkg/app"
	"github.com/cloudwego/hertz/pkg/app/server"
	"github.com/yxrxy/videoHub/app/gateway/drama"
	"github.com/yxrxy/videoHub/app/gateway/mw"
	"github.com/yxrxy/videoHub/app/gateway/pack"
	"github.com/yxrxy/videoHub/app/gateway/rpc"
	"github.com/yxrxy/videoHub/kitex_gen/interaction"
	metainfoContext "github.com/yxrxy/videoHub/pkg/base/context"
	"github.com/yxrxy/videoHub/pkg/errno"
)

// RegisterEpisodeInteractRoutes 评论/点赞挂 episode_id（底层复用 video_id 字段）。
func RegisterEpisodeInteractRoutes(h *server.Hertz) {
	g := h.Group("/api/v1/episode")

	g.GET("/:episode_id/comments", mw.OptionalAuth(), func(ctx context.Context, c *app.RequestContext) {
		epID, _ := strconv.ParseInt(c.Param("episode_id"), 10, 64)
		page, _ := strconv.ParseInt(c.DefaultQuery("page", "1"), 10, 32)
		size, _ := strconv.ParseInt(c.DefaultQuery("size", "20"), 10, 32)
		list, total, err := rpc.GetCommentsRPC(ctx, &interaction.GetCommentsRequest{
			VideoId: epID,
			Page:    int32(page),
			Size:    int32(size),
		})
		if err != nil {
			pack.RespError(c, err)
			return
		}
		pack.RespData(c, map[string]any{"list": list, "total": total})
	})

	// 当前用户是否已点赞 + 分集点赞数（播放页初始化用）
	g.GET("/:episode_id/like", mw.OptionalAuth(), func(ctx context.Context, c *app.RequestContext) {
		epID, _ := strconv.ParseInt(c.Param("episode_id"), 10, 64)
		liked, count := episodeLikeState(ctx, epID)
		pack.RespData(c, map[string]any{"liked": liked, "like_count": count})
	})

	auth := g.Group("/", mw.Auth())
	auth.POST("/:episode_id/comment", func(ctx context.Context, c *app.RequestContext) {
		epID, _ := strconv.ParseInt(c.Param("episode_id"), 10, 64)
		var body struct {
			Content  string `json:"content"`
			ParentID *int64 `json:"parent_id"`
		}
		if err := c.BindAndValidate(&body); err != nil || body.Content == "" {
			pack.RespError(c, errno.ParamVerifyError)
			return
		}
		parent := int64(-1)
		if body.ParentID != nil {
			parent = *body.ParentID
		}
		if err := rpc.CommentVideoRPC(ctx, &interaction.CommentRequest{
			VideoId:  epID,
			Content:  body.Content,
			ParentId: &parent,
		}); err != nil {
			pack.RespError(c, err)
			return
		}
		pack.RespSuccess(c)
	})

	auth.POST("/:episode_id/like", func(ctx context.Context, c *app.RequestContext) {
		epID, _ := strconv.ParseInt(c.Param("episode_id"), 10, 64)
		if err := rpc.LikeVideoRPC(ctx, &interaction.LikeRequest{VideoId: epID}); err != nil {
			pack.RespError(c, err)
			return
		}
		liked, count := episodeLikeState(ctx, epID)
		pack.RespData(c, map[string]any{"liked": liked, "like_count": count})
	})
}

func episodeLikeState(ctx context.Context, epID int64) (liked bool, count int64) {
	if ep, err := drama.GetEpisode(epID); err == nil && ep != nil {
		count = ep.LikeCount
	}
	uid, err := metainfoContext.GetUserID(ctx)
	if err != nil || uid <= 0 {
		return false, count
	}
	list, _, err := rpc.GetLikesRPC(ctx, &interaction.GetLikesRequest{
		VideoId: epID,
		Page:    1,
		Size:    200,
	})
	if err != nil {
		return false, count
	}
	for _, it := range list {
		if it != nil && it.UserId == uid {
			return true, count
		}
	}
	return false, count
}
