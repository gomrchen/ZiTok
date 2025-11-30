package rpc

import (
	"context"

	"github.com/yxrxy/videoHub/app/video/controllers/rpc/pack"
	"github.com/yxrxy/videoHub/app/video/domain/model"
	"github.com/yxrxy/videoHub/app/video/usecase"
	"github.com/yxrxy/videoHub/kitex_gen/video"
	"github.com/yxrxy/videoHub/pkg/base"
	pkgcontext "github.com/yxrxy/videoHub/pkg/base/context"
	"github.com/yxrxy/videoHub/pkg/constants"
)

type VideoHandler struct {
	useCase usecase.VideoUseCase
}

func NewVideoHandler(useCase usecase.VideoUseCase) *VideoHandler {
	return &VideoHandler{useCase: useCase}
}

func (h *VideoHandler) Publish(ctx context.Context, req *video.PublishRequest) (r *video.PublishResponse, err error) {
	r = new(video.PublishResponse)
	userID, err := pkgcontext.GetUserID(ctx)
	if err != nil {
		return r, err
	}
	description := ""
	if req.Description != nil {
		description = *req.Description
	}

	category := "all"
	if req.Category != nil {
		category = *req.Category
	}

	tags := make([]string, 0)
	if req.Tags != nil {
		tags = req.Tags
	}

	isPrivate := false
	if req.IsPrivate != nil {
		isPrivate = *req.IsPrivate
	}
	videoURL, err := h.useCase.Publish(ctx, userID, req.VideoData, req.ContentType, req.Title, &description, &category, tags, isPrivate)
	if err != nil {
		return r, err
	}
	r.Base = base.BuildBaseResp(err)
	r.VideoUrl = videoURL
	return r, err
}

func (h *VideoHandler) List(ctx context.Context, req *video.VideoListRequest) (r *video.VideoListResponse, err error) {
	r = new(video.VideoListResponse)
	userID := req.UserId
	var videoList []*model.Video
	var total int64
	if videoList, total, err = h.useCase.GetVideoList(ctx, userID, req.Page, req.Size, req.Category); err != nil {
		return
	}
	r.VideoList = pack.Videos(videoList)
	r.Total = total
	r.Base = base.BuildBaseResp(err)
	return
}

func (h *VideoHandler) Detail(ctx context.Context, req *video.DetailRequest) (r *video.DetailResponse, err error) {
	r = new(video.DetailResponse)
	userID, err := pkgcontext.GetUserID(ctx)
	if err != nil {
		return
	}

	var video *model.Video
	if video, err = h.useCase.GetVideoDetail(ctx, req.VideoId, userID); err != nil {
		return
	}
	r.Video = pack.Video(video)
	r.Base = base.BuildBaseResp(err)
	return
}

func (h *VideoHandler) GetHotVideos(ctx context.Context, req *video.HotVideoRequest) (r *video.HotVideoResponse, err error) {
	r = new(video.HotVideoResponse)

	var videoList []*model.Video
	var total int64
	var lastVisit, lastLike, lastID int64
	limit := int32(constants.DefaultPageSize)
	category := "all"
	ulastVisit := int64(0)
	ulastLike := int64(0)
	ulastID := int64(0)
	if req.Limit == nil {
		req.Limit = &limit
	}
	if req.Category == nil {
		req.Category = &category
	}
	if req.LastVisit == nil {
		req.LastVisit = &ulastVisit
	}
	if req.LastLike == nil {
		req.LastLike = &ulastLike
	}
	if req.LastId == nil {
		req.LastId = &ulastID
	}

	if videoList, total, lastVisit, lastLike, lastID, err = h.useCase.GetHotVideos(
		ctx,
		*req.Limit,
		*req.Category,
		*req.LastVisit,
		*req.LastLike,
		*req.LastId,
	); err != nil {
		return r, err
	}
	r.Videos = pack.Videos(videoList)
	r.Total = total
	r.NextVisit = &lastVisit
	r.NextLike = &lastLike
	r.NextId = &lastID
	r.Base = base.BuildBaseResp(err)
	return r, err
}

func (h *VideoHandler) Recommend(ctx context.Context, req *video.HotVideoRequest) (r *video.HotVideoResponse, err error) {
	r = new(video.HotVideoResponse)
	var videoList []*model.Video
	limit := int32(constants.DefaultPageSize)
	if req.Limit != nil {
		limit = *req.Limit
	}

	// 调用推荐接口（包含个性化 + 热门兜底）
	if videoList, err = h.useCase.RecommendVideos(ctx, limit); err != nil {
		return r, err
	}

	// 构造响应
	// 注意：推荐接口目前不返回分页游标，因此置为0
	zero := int64(0)
	r.Videos = pack.Videos(videoList)
	r.Total = int64(len(videoList))
	r.NextVisit = &zero
	r.NextLike = &zero
	r.NextId = &zero
	r.Base = base.BuildBaseResp(err)
	return r, err
}

func (h *VideoHandler) Delete(ctx context.Context, req *video.DeleteRequest) (r *video.DeleteResponse, err error) {
	r = new(video.DeleteResponse)

	userID, err := pkgcontext.GetUserID(ctx)
	if err != nil {
		return
	}
	if err = h.useCase.DeleteVideo(ctx, req.VideoId, userID); err != nil {
		return
	}
	r.Base = base.BuildBaseResp(err)
	return
}

func (h *VideoHandler) IncrementVisitCount(ctx context.Context, req *video.IncrementVisitCountRequest) (r *video.IncrementVisitCountResponse, err error) {
	r = new(video.IncrementVisitCountResponse)

	if err = h.useCase.IncrementVisitCount(ctx, req.VideoId); err != nil {
		return
	}
	r.Base = base.BuildBaseResp(err)
	return
}

func (h *VideoHandler) IncrementLikeCount(ctx context.Context, req *video.IncrementLikeCountRequest) (r *video.IncrementLikeCountResponse, err error) {
	r = new(video.IncrementLikeCountResponse)

	if err = h.useCase.IncrementLikeCount(ctx, req.VideoId); err != nil {
		return
	}
	r.Base = base.BuildBaseResp(err)
	return
}

func (h *VideoHandler) Search(ctx context.Context, req *video.SearchRequest) (r *video.SearchResponse, err error) {
	r = new(video.SearchResponse)

	var videoList []*model.Video
	var total int64
	if videoList, total, err = h.useCase.SearchVideo(ctx, req.Keywords, req.PageSize, req.PageNum, req.FromDate, req.ToDate, req.Username); err != nil {
		return
	}
	r.Videos = pack.Videos(videoList)
	r.Total = total
	r.Base = base.BuildBaseResp(err)
	return
}

func (h *VideoHandler) SemanticSearch(ctx context.Context, req *video.SemanticSearchRequest) (r *video.SemanticSearchResponse, err error) {
	r = new(video.SemanticSearchResponse)

	var result []*model.SemanticSearchResultItem
	if result, err = h.useCase.SemanticSearch(ctx, req.Query, req.PageSize, req.PageNum, *req.Threshold); err != nil {
		return
	}
	r.Results = pack.SemanticSearchResultItems(result)
	r.Base = base.BuildBaseResp(err)
	return
}

func (h *VideoHandler) UploadCover(ctx context.Context, req *video.UploadCoverRequest) (r *video.UploadCoverResponse, err error) {
	r = new(video.UploadCoverResponse)

	coverURL, err := h.useCase.UploadCover(ctx, req.VideoId, req.CoverData, req.ContentType)
	if err != nil {
		return r, err
	}

	r.Base = base.BuildBaseResp(nil)
	r.CoverUrl = coverURL
	return r, nil
}
