package drama

import (
	"context"
	"strconv"

	"github.com/cloudwego/hertz/pkg/app"
	"github.com/yxrxy/videoHub/app/gateway/pack"
	"github.com/yxrxy/videoHub/app/gateway/rpc"
	pkgcontext "github.com/yxrxy/videoHub/pkg/base/context"
	"github.com/yxrxy/videoHub/pkg/errno"
)

func ListDramas(ctx context.Context, c *app.RequestContext) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	size, _ := strconv.Atoi(c.DefaultQuery("size", "20"))
	list, total, err := rpc.ListDramasRPC(ctx, int32(page), int32(size), c.Query("category"), nil)
	if err != nil {
		pack.RespError(c, err)
		return
	}
	pack.RespData(c, map[string]any{"list": list, "total": total, "page": page, "size": size})
}

func GetDramaDetail(ctx context.Context, c *app.RequestContext) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil || id <= 0 {
		pack.RespError(c, errno.ParamVerifyError)
		return
	}
	uid, _ := pkgcontext.GetUserID(ctx)
	d, eps, fav, err := rpc.GetDramaDetailRPC(ctx, id, uid)
	if err != nil {
		pack.RespError(c, errno.NewErrNo(errno.InternalServiceErrorCode, "剧不存在"))
		return
	}
	pack.RespData(c, map[string]any{"drama": d, "episodes": eps, "favorite": fav})
}

func ListEpisodes(ctx context.Context, c *app.RequestContext) {
	id, _ := strconv.ParseInt(c.Param("id"), 10, 64)
	eps, err := rpc.ListEpisodesRPC(ctx, id)
	if err != nil {
		pack.RespError(c, err)
		return
	}
	pack.RespData(c, map[string]any{"list": eps})
}

func GetFeed(ctx context.Context, c *app.RequestContext) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	size, _ := strconv.Atoi(c.DefaultQuery("size", "10"))
	uid, _ := pkgcontext.GetUserID(ctx)
	items, err := rpc.GetFeedRPC(ctx, uid, int32(page), int32(size))
	if err != nil {
		pack.RespError(c, err)
		return
	}
	pack.RespData(c, map[string]any{"list": items, "page": page, "size": size})
}

func GetPlayInfo(ctx context.Context, c *app.RequestContext) {
	epID, _ := strconv.ParseInt(c.Param("episode_id"), 10, 64)
	uid, _ := pkgcontext.GetUserID(ctx)
	info, err := rpc.GetPlayInfoRPC(ctx, epID, uid)
	if err != nil {
		pack.RespError(c, errno.NewErrNo(errno.InternalServiceErrorCode, "集不存在"))
		return
	}
	pack.RespData(c, info)
}

func ReportProgress(ctx context.Context, c *app.RequestContext) {
	uid, err := pkgcontext.GetUserID(ctx)
	if err != nil || uid <= 0 {
		pack.RespError(c, errno.NewErrNo(errno.AuthInvalidCode, "未登录"))
		return
	}
	var body struct {
		DramaID     int64 `json:"drama_id"`
		EpisodeID   int64 `json:"episode_id"`
		EpisodeNo   int32 `json:"episode_no"`
		PositionSec int32 `json:"position_sec"`
	}
	if err := c.BindAndValidate(&body); err != nil {
		pack.RespError(c, errno.ParamVerifyError.WithError(err))
		return
	}
	if err := rpc.ReportProgressRPC(ctx, uid, body.DramaID, body.EpisodeID, body.EpisodeNo, body.PositionSec); err != nil {
		pack.RespError(c, err)
		return
	}
	pack.RespSuccess(c)
}

func ContinueWatching(ctx context.Context, c *app.RequestContext) {
	uid, err := pkgcontext.GetUserID(ctx)
	if err != nil || uid <= 0 {
		pack.RespError(c, errno.NewErrNo(errno.AuthInvalidCode, "未登录"))
		return
	}
	list, err := rpc.ContinueWatchingRPC(ctx, uid)
	if err != nil {
		pack.RespError(c, err)
		return
	}
	// 兼容 Flutter ContinueItem：嵌套 progress
	out := make([]map[string]any, 0, len(list))
	for _, it := range list {
		out = append(out, map[string]any{
			"progress": map[string]any{
				"drama_id":     it.DramaId,
				"episode_id":   it.EpisodeId,
				"episode_no":   it.EpisodeNo,
				"position_sec": it.PositionSec,
			},
			"drama":   it.Drama,
			"episode": it.Episode,
		})
	}
	pack.RespData(c, map[string]any{"list": out})
}

func Favorite(ctx context.Context, c *app.RequestContext) {
	uid, err := pkgcontext.GetUserID(ctx)
	if err != nil || uid <= 0 {
		pack.RespError(c, errno.NewErrNo(errno.AuthInvalidCode, "未登录"))
		return
	}
	id, _ := strconv.ParseInt(c.Param("id"), 10, 64)
	if err := rpc.FavoriteRPC(ctx, uid, id, false); err != nil {
		pack.RespError(c, err)
		return
	}
	pack.RespSuccess(c)
}

func Unfavorite(ctx context.Context, c *app.RequestContext) {
	uid, err := pkgcontext.GetUserID(ctx)
	if err != nil || uid <= 0 {
		pack.RespError(c, errno.NewErrNo(errno.AuthInvalidCode, "未登录"))
		return
	}
	id, _ := strconv.ParseInt(c.Param("id"), 10, 64)
	if err := rpc.FavoriteRPC(ctx, uid, id, true); err != nil {
		pack.RespError(c, err)
		return
	}
	pack.RespSuccess(c)
}

func ListFavorites(ctx context.Context, c *app.RequestContext) {
	uid, err := pkgcontext.GetUserID(ctx)
	if err != nil || uid <= 0 {
		pack.RespError(c, errno.NewErrNo(errno.AuthInvalidCode, "未登录"))
		return
	}
	list, err := rpc.ListFavoritesRPC(ctx, uid)
	if err != nil {
		pack.RespError(c, err)
		return
	}
	pack.RespData(c, map[string]any{"list": list})
}

func SearchDramas(ctx context.Context, c *app.RequestContext) {
	q := c.Query("q")
	if q == "" {
		q = c.Query("keyword")
	}
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	size, _ := strconv.Atoi(c.DefaultQuery("size", "20"))
	list, total, err := rpc.SearchDramasRPC(ctx, q, int32(page), int32(size))
	if err != nil {
		pack.RespError(c, err)
		return
	}
	pack.RespData(c, map[string]any{"list": list, "total": total})
}
