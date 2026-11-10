package handler

import (
	"context"

	"github.com/yxrxy/videoHub/app/drama"
	kdrama "github.com/yxrxy/videoHub/kitex_gen/drama"
	base "github.com/yxrxy/videoHub/pkg/base"
)

type DramaServiceImpl struct{}

func New() *DramaServiceImpl { return &DramaServiceImpl{} }

func toDramaInfo(d *drama.Drama) *kdrama.DramaInfo {
	if d == nil {
		return nil
	}
	return &kdrama.DramaInfo{
		Id:               d.ID,
		Title:            d.Title,
		CoverUrl:         d.CoverURL,
		Description:      d.Description,
		Category:         d.Category,
		Tags:             d.Tags,
		TotalEpisodes:    int32(d.TotalEpisodes),
		FreeEpisodeCount: int32(d.FreeEpisodeCount),
		BundlePrice:      int32(d.BundlePrice),
		Status:           d.Status,
		PlayCount:        d.PlayCount,
		LikeCount:        d.LikeCount,
	}
}

func toEpisodeInfo(e *drama.Episode) *kdrama.EpisodeInfo {
	if e == nil {
		return nil
	}
	return &kdrama.EpisodeInfo{
		Id:          e.ID,
		DramaId:     e.DramaID,
		EpisodeNo:   int32(e.EpisodeNo),
		Title:       e.Title,
		VideoUrl:    e.VideoURL,
		CoverUrl:    e.CoverURL,
		Duration:    e.Duration,
		IsFree:      e.IsFree,
		UnlockPrice: int32(e.UnlockPrice),
		VisitCount:  e.VisitCount,
		LikeCount:   e.LikeCount,
	}
}

func (s *DramaServiceImpl) ListDramas(ctx context.Context, req *kdrama.ListDramasRequest) (*kdrama.ListDramasResponse, error) {
	resp := kdrama.NewListDramasResponse()
	resp.Base = base.BuildBaseResp(nil)
	var st *int8
	if req.IsSetStatus() {
		v := req.GetStatus()
		st = &v
	}
	list, total, err := drama.ListDramas(int(req.Page), int(req.Size), req.GetCategory(), st)
	if err != nil {
		return nil, err
	}
	resp.Total = total
	resp.List = make([]*kdrama.DramaInfo, 0, len(list))
	for i := range list {
		resp.List = append(resp.List, toDramaInfo(&list[i]))
	}
	return resp, nil
}

func (s *DramaServiceImpl) GetDramaDetail(ctx context.Context, req *kdrama.GetDramaDetailRequest) (*kdrama.GetDramaDetailResponse, error) {
	resp := kdrama.NewGetDramaDetailResponse()
	resp.Base = base.BuildBaseResp(nil)
	d, err := drama.GetDrama(req.DramaId)
	if err != nil {
		return nil, err
	}
	eps, err := drama.ListEpisodes(req.DramaId)
	if err != nil {
		return nil, err
	}
	resp.Drama = toDramaInfo(d)
	resp.Episodes = make([]*kdrama.EpisodeInfo, 0, len(eps))
	for i := range eps {
		resp.Episodes = append(resp.Episodes, toEpisodeInfo(&eps[i]))
	}
	uid := req.GetUserId()
	if uid > 0 {
		resp.Favorite = drama.IsFavorite(uid, req.DramaId)
	}
	return resp, nil
}

func (s *DramaServiceImpl) ListEpisodes(ctx context.Context, req *kdrama.ListEpisodesRequest) (*kdrama.ListEpisodesResponse, error) {
	resp := kdrama.NewListEpisodesResponse()
	resp.Base = base.BuildBaseResp(nil)
	eps, err := drama.ListEpisodes(req.DramaId)
	if err != nil {
		return nil, err
	}
	resp.List = make([]*kdrama.EpisodeInfo, 0, len(eps))
	for i := range eps {
		resp.List = append(resp.List, toEpisodeInfo(&eps[i]))
	}
	return resp, nil
}

func (s *DramaServiceImpl) GetFeed(ctx context.Context, req *kdrama.GetFeedRequest) (*kdrama.GetFeedResponse, error) {
	resp := kdrama.NewGetFeedResponse()
	resp.Base = base.BuildBaseResp(nil)
	items, err := drama.BuildFeed(req.GetUserId(), int(req.Page), int(req.Size))
	if err != nil {
		return nil, err
	}
	resp.List = make([]*kdrama.FeedItem, 0, len(items))
	for i := range items {
		resp.List = append(resp.List, &kdrama.FeedItem{
			Drama:   toDramaInfo(&items[i].Drama),
			Episode: toEpisodeInfo(&items[i].Episode),
			Locked:  items[i].Locked,
		})
	}
	return resp, nil
}

func (s *DramaServiceImpl) GetPlayInfo(ctx context.Context, req *kdrama.GetPlayInfoRequest) (*kdrama.GetPlayInfoResponse, error) {
	resp := kdrama.NewGetPlayInfoResponse()
	resp.Base = base.BuildBaseResp(nil)
	ep, err := drama.GetEpisode(req.EpisodeId)
	if err != nil {
		return nil, err
	}
	d, err := drama.GetDrama(ep.DramaID)
	if err != nil {
		return nil, err
	}
	uid := req.GetUserId()
	free := drama.IsEpisodeFree(d, ep)
	unlocked := free || drama.HasUnlock(uid, d.ID, ep.ID)
	info := kdrama.NewPlayInfo()
	info.Episode = toEpisodeInfo(ep)
	info.Drama = toDramaInfo(d)
	info.Locked = !unlocked
	info.UnlockPrice = int32(ep.UnlockPrice)
	info.CanPlay = unlocked
	if unlocked {
		info.VideoUrl = &ep.VideoURL
	}
	resp.Info = info
	return resp, nil
}

func (s *DramaServiceImpl) ReportProgress(ctx context.Context, req *kdrama.ReportProgressRequest) (*kdrama.ReportProgressResponse, error) {
	resp := kdrama.NewReportProgressResponse()
	resp.Base = base.BuildBaseResp(nil)
	err := drama.UpsertProgress(&drama.WatchProgress{
		UserID:      req.UserId,
		DramaID:     req.DramaId,
		EpisodeID:   req.EpisodeId,
		EpisodeNo:   int(req.EpisodeNo),
		PositionSec: int(req.PositionSec),
	})
	return resp, err
}

func (s *DramaServiceImpl) ContinueWatching(ctx context.Context, req *kdrama.ContinueWatchingRequest) (*kdrama.ContinueWatchingResponse, error) {
	resp := kdrama.NewContinueWatchingResponse()
	resp.Base = base.BuildBaseResp(nil)
	list, err := drama.ListContinueWatching(req.UserId, int(req.GetLimit()))
	if err != nil {
		return nil, err
	}
	resp.List = make([]*kdrama.ContinueItem, 0, len(list))
	for _, p := range list {
		item := &kdrama.ContinueItem{
			DramaId:     p.DramaID,
			EpisodeId:   p.EpisodeID,
			EpisodeNo:   int32(p.EpisodeNo),
			PositionSec: int32(p.PositionSec),
		}
		if d, e := drama.GetDrama(p.DramaID); e == nil {
			item.Drama = toDramaInfo(d)
		}
		if ep, e := drama.GetEpisode(p.EpisodeID); e == nil {
			item.Episode = toEpisodeInfo(ep)
		}
		resp.List = append(resp.List, item)
	}
	return resp, nil
}

func (s *DramaServiceImpl) Favorite(ctx context.Context, req *kdrama.FavoriteRequest) (*kdrama.FavoriteResponse, error) {
	resp := kdrama.NewFavoriteResponse()
	resp.Base = base.BuildBaseResp(nil)
	return resp, drama.Favorite(req.UserId, req.DramaId)
}

func (s *DramaServiceImpl) Unfavorite(ctx context.Context, req *kdrama.FavoriteRequest) (*kdrama.FavoriteResponse, error) {
	resp := kdrama.NewFavoriteResponse()
	resp.Base = base.BuildBaseResp(nil)
	return resp, drama.Unfavorite(req.UserId, req.DramaId)
}

func (s *DramaServiceImpl) ListFavorites(ctx context.Context, req *kdrama.ListFavoritesRequest) (*kdrama.ListFavoritesResponse, error) {
	resp := kdrama.NewListFavoritesResponse()
	resp.Base = base.BuildBaseResp(nil)
	list, err := drama.ListFavorites(req.UserId)
	if err != nil {
		return nil, err
	}
	resp.List = make([]*kdrama.DramaInfo, 0, len(list))
	for i := range list {
		resp.List = append(resp.List, toDramaInfo(&list[i]))
	}
	return resp, nil
}

func (s *DramaServiceImpl) SearchDramas(ctx context.Context, req *kdrama.SearchDramasRequest) (*kdrama.SearchDramasResponse, error) {
	resp := kdrama.NewSearchDramasResponse()
	resp.Base = base.BuildBaseResp(nil)
	list, total, err := drama.SearchDramas(req.Keyword, int(req.Page), int(req.Size))
	if err != nil {
		return nil, err
	}
	resp.Total = total
	resp.List = make([]*kdrama.DramaInfo, 0, len(list))
	for i := range list {
		resp.List = append(resp.List, toDramaInfo(&list[i]))
	}
	return resp, nil
}

func (s *DramaServiceImpl) CreateDrama(ctx context.Context, req *kdrama.CreateDramaRequest) (*kdrama.CreateDramaResponse, error) {
	resp := kdrama.NewCreateDramaResponse()
	resp.Base = base.BuildBaseResp(nil)
	d := &drama.Drama{
		Title:            req.Title,
		CoverURL:         req.GetCoverUrl(),
		Description:      req.GetDescription(),
		Category:         req.GetCategory(),
		Tags:             req.GetTags(),
		FreeEpisodeCount: int(req.GetFreeEpisodeCount()),
		BundlePrice:      int(req.GetBundlePrice()),
		Status:           req.GetStatus(),
	}
	if d.FreeEpisodeCount == 0 {
		d.FreeEpisodeCount = 3
	}
	if d.Status == 0 {
		d.Status = 1
	}
	if err := drama.CreateDrama(d); err != nil {
		return nil, err
	}
	resp.Drama = toDramaInfo(d)
	return resp, nil
}

func (s *DramaServiceImpl) UpdateDrama(ctx context.Context, req *kdrama.UpdateDramaRequest) (*kdrama.UpdateDramaResponse, error) {
	resp := kdrama.NewUpdateDramaResponse()
	resp.Base = base.BuildBaseResp(nil)
	d := &drama.Drama{ID: req.DramaId}
	if req.IsSetTitle() {
		d.Title = req.GetTitle()
	}
	if req.IsSetCoverUrl() {
		d.CoverURL = req.GetCoverUrl()
	}
	if req.IsSetDescription() {
		d.Description = req.GetDescription()
	}
	if req.IsSetCategory() {
		d.Category = req.GetCategory()
	}
	if req.IsSetTags() {
		d.Tags = req.GetTags()
	}
	if req.IsSetFreeEpisodeCount() {
		d.FreeEpisodeCount = int(req.GetFreeEpisodeCount())
	}
	if req.IsSetBundlePrice() {
		d.BundlePrice = int(req.GetBundlePrice())
	}
	if req.IsSetStatus() {
		d.Status = req.GetStatus()
	}
	if err := drama.UpdateDrama(d); err != nil {
		return nil, err
	}
	got, _ := drama.GetDrama(req.DramaId)
	resp.Drama = toDramaInfo(got)
	return resp, nil
}

func (s *DramaServiceImpl) OfflineDrama(ctx context.Context, req *kdrama.OfflineDramaRequest) (*kdrama.OfflineDramaResponse, error) {
	resp := kdrama.NewOfflineDramaResponse()
	resp.Base = base.BuildBaseResp(nil)
	return resp, drama.SoftDeleteDrama(req.DramaId)
}

func (s *DramaServiceImpl) CreateEpisode(ctx context.Context, req *kdrama.CreateEpisodeRequest) (*kdrama.CreateEpisodeResponse, error) {
	resp := kdrama.NewCreateEpisodeResponse()
	resp.Base = base.BuildBaseResp(nil)
	ep := &drama.Episode{
		DramaID:     req.DramaId,
		EpisodeNo:   int(req.EpisodeNo),
		Title:       req.Title,
		VideoURL:    req.VideoUrl,
		CoverURL:    req.GetCoverUrl(),
		IsFree:      req.GetIsFree(),
		UnlockPrice: int(req.GetUnlockPrice()),
		Duration:    req.GetDuration(),
	}
	if ep.UnlockPrice == 0 {
		ep.UnlockPrice = 10
	}
	if ep.Duration == 0 {
		ep.Duration = 60
	}
	if err := drama.CreateEpisode(ep); err != nil {
		return nil, err
	}
	resp.Episode = toEpisodeInfo(ep)
	return resp, nil
}

func (s *DramaServiceImpl) UpdateEpisode(ctx context.Context, req *kdrama.UpdateEpisodeRequest) (*kdrama.UpdateEpisodeResponse, error) {
	resp := kdrama.NewUpdateEpisodeResponse()
	resp.Base = base.BuildBaseResp(nil)
	ep := &drama.Episode{ID: req.EpisodeId}
	if req.IsSetTitle() {
		ep.Title = req.GetTitle()
	}
	if req.IsSetVideoUrl() {
		ep.VideoURL = req.GetVideoUrl()
	}
	if req.IsSetCoverUrl() {
		ep.CoverURL = req.GetCoverUrl()
	}
	if req.IsSetIsFree() {
		ep.IsFree = req.GetIsFree()
	}
	if req.IsSetUnlockPrice() {
		ep.UnlockPrice = int(req.GetUnlockPrice())
	}
	if req.IsSetEpisodeNo() {
		ep.EpisodeNo = int(req.GetEpisodeNo())
	}
	if err := drama.UpdateEpisode(ep); err != nil {
		return nil, err
	}
	got, _ := drama.GetEpisode(req.EpisodeId)
	resp.Episode = toEpisodeInfo(got)
	return resp, nil
}
