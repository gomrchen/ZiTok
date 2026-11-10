package rpc

import (
	"context"
	"log"

	local "github.com/yxrxy/videoHub/app/drama"
	"github.com/yxrxy/videoHub/kitex_gen/drama"
	"github.com/yxrxy/videoHub/kitex_gen/drama/dramaservice"
	"github.com/yxrxy/videoHub/pkg/base/client"
	"github.com/yxrxy/videoHub/pkg/errno"
)

var dramaClient dramaservice.Client
var dramaRPCReady bool

func InitDramaRPC() {
	c, err := client.InitDramaRPC()
	if err != nil {
		log.Printf("[gateway] Drama RPC 不可用，使用本地领域降级: %v", err)
		dramaRPCReady = false
		return
	}
	dramaClient = *c
	dramaRPCReady = true
	log.Printf("[gateway] Drama RPC ready")
}

func ListDramasRPC(ctx context.Context, page, size int32, category string, status *int8) ([]*drama.DramaInfo, int64, error) {
	if dramaRPCReady {
		req := &drama.ListDramasRequest{Page: page, Size: size}
		if category != "" {
			req.Category = &category
		}
		if status != nil {
			req.Status = status
		}
		resp, err := dramaClient.ListDramas(ctx, req)
		if err == nil && resp != nil && resp.Base != nil && resp.Base.Code == errno.SuccessCode {
			return resp.List, resp.Total, nil
		}
		if err != nil {
			log.Printf("[gateway] ListDramas RPC fail, fallback: %v", err)
		}
	}
	list, total, err := local.ListDramas(int(page), int(size), category, status)
	if err != nil {
		return nil, 0, err
	}
	out := make([]*drama.DramaInfo, 0, len(list))
	for i := range list {
		out = append(out, localToDramaInfo(&list[i]))
	}
	return out, total, nil
}

func GetDramaDetailRPC(ctx context.Context, dramaID, userID int64) (*drama.DramaInfo, []*drama.EpisodeInfo, bool, error) {
	if dramaRPCReady {
		req := &drama.GetDramaDetailRequest{DramaId: dramaID}
		if userID > 0 {
			req.UserId = &userID
		}
		resp, err := dramaClient.GetDramaDetail(ctx, req)
		if err == nil && resp != nil && resp.Base != nil && resp.Base.Code == errno.SuccessCode {
			return resp.Drama, resp.Episodes, resp.Favorite, nil
		}
		if err != nil {
			log.Printf("[gateway] GetDramaDetail RPC fail, fallback: %v", err)
		}
	}
	d, err := local.GetDrama(dramaID)
	if err != nil {
		return nil, nil, false, err
	}
	eps, err := local.ListEpisodes(dramaID)
	if err != nil {
		return nil, nil, false, err
	}
	outEps := make([]*drama.EpisodeInfo, 0, len(eps))
	for i := range eps {
		outEps = append(outEps, localToEpisodeInfo(&eps[i]))
	}
	fav := userID > 0 && local.IsFavorite(userID, dramaID)
	return localToDramaInfo(d), outEps, fav, nil
}

func GetFeedRPC(ctx context.Context, userID int64, page, size int32) ([]*drama.FeedItem, error) {
	if dramaRPCReady {
		req := &drama.GetFeedRequest{Page: page, Size: size}
		if userID > 0 {
			req.UserId = &userID
		}
		resp, err := dramaClient.GetFeed(ctx, req)
		if err == nil && resp != nil && resp.Base != nil && resp.Base.Code == errno.SuccessCode {
			return resp.List, nil
		}
		if err != nil {
			log.Printf("[gateway] GetFeed RPC fail, fallback: %v", err)
		}
	}
	items, err := local.BuildFeed(userID, int(page), int(size))
	if err != nil {
		return nil, err
	}
	out := make([]*drama.FeedItem, 0, len(items))
	for i := range items {
		out = append(out, &drama.FeedItem{
			Drama:   localToDramaInfo(&items[i].Drama),
			Episode: localToEpisodeInfo(&items[i].Episode),
			Locked:  items[i].Locked,
		})
	}
	return out, nil
}

func GetPlayInfoRPC(ctx context.Context, episodeID, userID int64) (*drama.PlayInfo, error) {
	if dramaRPCReady {
		req := &drama.GetPlayInfoRequest{EpisodeId: episodeID}
		if userID > 0 {
			req.UserId = &userID
		}
		resp, err := dramaClient.GetPlayInfo(ctx, req)
		if err == nil && resp != nil && resp.Base != nil && resp.Base.Code == errno.SuccessCode {
			return resp.Info, nil
		}
		if err != nil {
			log.Printf("[gateway] GetPlayInfo RPC fail, fallback: %v", err)
		}
	}
	ep, err := local.GetEpisode(episodeID)
	if err != nil {
		return nil, err
	}
	d, err := local.GetDrama(ep.DramaID)
	if err != nil {
		return nil, err
	}
	free := local.IsEpisodeFree(d, ep)
	unlocked := free || local.HasUnlock(userID, d.ID, ep.ID)
	info := drama.NewPlayInfo()
	info.Episode = localToEpisodeInfo(ep)
	info.Drama = localToDramaInfo(d)
	info.Locked = !unlocked
	info.UnlockPrice = int32(ep.UnlockPrice)
	info.CanPlay = unlocked
	if unlocked {
		info.VideoUrl = &ep.VideoURL
	}
	return info, nil
}

func ReportProgressRPC(ctx context.Context, userID, dramaID, episodeID int64, episodeNo, pos int32) error {
	if dramaRPCReady {
		_, err := dramaClient.ReportProgress(ctx, &drama.ReportProgressRequest{
			UserId: userID, DramaId: dramaID, EpisodeId: episodeID, EpisodeNo: episodeNo, PositionSec: pos,
		})
		if err == nil {
			return nil
		}
		log.Printf("[gateway] ReportProgress RPC fail, fallback: %v", err)
	}
	return local.UpsertProgress(&local.WatchProgress{
		UserID: userID, DramaID: dramaID, EpisodeID: episodeID, EpisodeNo: int(episodeNo), PositionSec: int(pos),
	})
}

func ContinueWatchingRPC(ctx context.Context, userID int64) ([]*drama.ContinueItem, error) {
	if dramaRPCReady {
		lim := int32(20)
		resp, err := dramaClient.ContinueWatching(ctx, &drama.ContinueWatchingRequest{UserId: userID, Limit: &lim})
		if err == nil && resp != nil && resp.Base != nil && resp.Base.Code == errno.SuccessCode {
			return resp.List, nil
		}
		if err != nil {
			log.Printf("[gateway] ContinueWatching RPC fail, fallback: %v", err)
		}
	}
	list, err := local.ListContinueWatching(userID, 20)
	if err != nil {
		return nil, err
	}
	out := make([]*drama.ContinueItem, 0, len(list))
	for _, p := range list {
		item := &drama.ContinueItem{
			DramaId: p.DramaID, EpisodeId: p.EpisodeID, EpisodeNo: int32(p.EpisodeNo), PositionSec: int32(p.PositionSec),
		}
		if d, e := local.GetDrama(p.DramaID); e == nil {
			item.Drama = localToDramaInfo(d)
		}
		if ep, e := local.GetEpisode(p.EpisodeID); e == nil {
			item.Episode = localToEpisodeInfo(ep)
		}
		out = append(out, item)
	}
	return out, nil
}

func FavoriteRPC(ctx context.Context, userID, dramaID int64, unfav bool) error {
	req := &drama.FavoriteRequest{UserId: userID, DramaId: dramaID}
	if dramaRPCReady {
		var err error
		if unfav {
			_, err = dramaClient.Unfavorite(ctx, req)
		} else {
			_, err = dramaClient.Favorite(ctx, req)
		}
		if err == nil {
			return nil
		}
		log.Printf("[gateway] Favorite RPC fail, fallback: %v", err)
	}
	if unfav {
		return local.Unfavorite(userID, dramaID)
	}
	return local.Favorite(userID, dramaID)
}

func ListFavoritesRPC(ctx context.Context, userID int64) ([]*drama.DramaInfo, error) {
	if dramaRPCReady {
		resp, err := dramaClient.ListFavorites(ctx, &drama.ListFavoritesRequest{UserId: userID})
		if err == nil && resp != nil && resp.Base != nil && resp.Base.Code == errno.SuccessCode {
			return resp.List, nil
		}
		if err != nil {
			log.Printf("[gateway] ListFavorites RPC fail, fallback: %v", err)
		}
	}
	list, err := local.ListFavorites(userID)
	if err != nil {
		return nil, err
	}
	out := make([]*drama.DramaInfo, 0, len(list))
	for i := range list {
		out = append(out, localToDramaInfo(&list[i]))
	}
	return out, nil
}

func SearchDramasRPC(ctx context.Context, keyword string, page, size int32) ([]*drama.DramaInfo, int64, error) {
	if dramaRPCReady {
		resp, err := dramaClient.SearchDramas(ctx, &drama.SearchDramasRequest{Keyword: keyword, Page: page, Size: size})
		if err == nil && resp != nil && resp.Base != nil && resp.Base.Code == errno.SuccessCode {
			return resp.List, resp.Total, nil
		}
		if err != nil {
			log.Printf("[gateway] SearchDramas RPC fail, fallback: %v", err)
		}
	}
	list, total, err := local.SearchDramas(keyword, int(page), int(size))
	if err != nil {
		return nil, 0, err
	}
	out := make([]*drama.DramaInfo, 0, len(list))
	for i := range list {
		out = append(out, localToDramaInfo(&list[i]))
	}
	return out, total, nil
}

func ListEpisodesRPC(ctx context.Context, dramaID int64) ([]*drama.EpisodeInfo, error) {
	if dramaRPCReady {
		resp, err := dramaClient.ListEpisodes(ctx, &drama.ListEpisodesRequest{DramaId: dramaID})
		if err == nil && resp != nil && resp.Base != nil && resp.Base.Code == errno.SuccessCode {
			return resp.List, nil
		}
		if err != nil {
			log.Printf("[gateway] ListEpisodes RPC fail, fallback: %v", err)
		}
	}
	eps, err := local.ListEpisodes(dramaID)
	if err != nil {
		return nil, err
	}
	out := make([]*drama.EpisodeInfo, 0, len(eps))
	for i := range eps {
		out = append(out, localToEpisodeInfo(&eps[i]))
	}
	return out, nil
}

func localToDramaInfo(d *local.Drama) *drama.DramaInfo {
	if d == nil {
		return nil
	}
	return &drama.DramaInfo{
		Id: d.ID, Title: d.Title, CoverUrl: d.CoverURL, Description: d.Description,
		Category: d.Category, Tags: d.Tags, TotalEpisodes: int32(d.TotalEpisodes),
		FreeEpisodeCount: int32(d.FreeEpisodeCount), BundlePrice: int32(d.BundlePrice),
		Status: d.Status, PlayCount: d.PlayCount, LikeCount: d.LikeCount,
	}
}

func localToEpisodeInfo(e *local.Episode) *drama.EpisodeInfo {
	if e == nil {
		return nil
	}
	return &drama.EpisodeInfo{
		Id: e.ID, DramaId: e.DramaID, EpisodeNo: int32(e.EpisodeNo), Title: e.Title,
		VideoUrl: e.VideoURL, CoverUrl: e.CoverURL, Duration: e.Duration, IsFree: e.IsFree,
		UnlockPrice: int32(e.UnlockPrice), VisitCount: e.VisitCount, LikeCount: e.LikeCount,
	}
}
