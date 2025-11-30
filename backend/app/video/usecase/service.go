package usecase

import (
    "context"
    "time"

    "github.com/yxrxy/videoHub/app/video/domain/model"
    "github.com/yxrxy/videoHub/pkg/errno"
    pkgcontext "github.com/yxrxy/videoHub/pkg/base/context"
)

func (s *useCase) Publish(ctx context.Context, userID int64, videoData []byte, contentType,
	title string, description, category *string, tags []string, isPrivate bool,
) (string, error) {
	if !s.svc.CheckVideo(ctx, videoData, contentType) {
		return "", errno.NewErrNo(errno.ServiceUserExist, "video format error")
	}
	videoPath, err := s.svc.SaveVideo(ctx, userID, videoData, contentType, title, description, category, tags, isPrivate)
	if err != nil {
		return "", err
	}

	return videoPath, nil
}

func (s *useCase) GetVideoList(ctx context.Context, userID, page int64, size int32, category *string) ([]*model.Video, int64, error) {
	return s.svc.GetVideoList(ctx, userID, page, size, category)
}

func (s *useCase) SearchVideo(
	ctx context.Context,
	keywords string,
	pageSize, pageNum int32,
	fromDate, toDate *int64,
	username *string,
) ([]*model.Video, int64, error) {
	videoES := &model.VideoES{
		Keywords: keywords,
		Username: username,
		FromDate: fromDate,
		ToDate:   toDate,
	}
	videoList, total, err := s.es.SearchItems(ctx, "video", videoES)
	if err != nil {
		return nil, 0, err
	}
	// TODO: 分页
	var res []*model.Video
	for _, videoID := range videoList {
		detail, err := s.GetVideoDetail(ctx, videoID, 0)
		if err != nil {
			return nil, 0, err
		}
		res = append(res, detail)
	}
	return res, total, nil
}

func (s *useCase) GetVideoDetail(ctx context.Context, videoID, userID int64) (*model.Video, error) {
	return s.svc.GetVideoDetail(ctx, videoID, userID)
}

func (s *useCase) GetHotVideos(
	ctx context.Context,
	limit int32,
	category string,
	lastVisit, lastLike, lastID int64,
) ([]*model.Video, int64, int64, int64, int64, error) {
	return s.svc.GetHotVideos(ctx, limit, category, lastVisit, lastLike, lastID)
}

func (s *useCase) RecommendVideos(
	ctx context.Context,
	limit int32,
) ([]*model.Video, error) {
	// 1. 尝试个性化推荐
	videos, err := s.svc.RecommendVideos(ctx, limit)
	if err == nil && len(videos) > 0 {
		return videos, nil
	}
	
	// 2. 降级为热门视频
	// 注意：GetHotVideos返回 cursor 等分页信息，这里我们只需要列表
	hotVideos, _, _, _, _, err := s.svc.GetHotVideos(ctx, limit, "all", 0, 0, 0)
	if err != nil {
		return nil, err
	}
	return hotVideos, nil
}

func (s *useCase) DeleteVideo(ctx context.Context, videoID, userID int64) error {
	video, err := s.db.GetVideoByID(ctx, videoID)
	if err != nil {
		return err
	}
	if video.UserID != userID {
		return errno.NewErrNo(errno.InternalServiceErrorCode, "无权限删除该视频")
	}
	err = s.es.RemoveItem(ctx, "video", videoID)
	if err != nil {
		return err
	}
	err = s.svc.DeleteVideoEmbedding(ctx, videoID)
	if err != nil {
		return err
	}
	s.svc.ClearRelatedCache(video.Category)
	return s.db.DeleteVideo(ctx, videoID)
}

func (s *useCase) IncrementVisitCount(ctx context.Context, videoID int64) error {
    if err := s.db.IncrementVisitCount(ctx, videoID); err != nil {
        return err
    }
    if uid, err := pkgcontext.GetUserID(ctx); err == nil && uid > 0 {
        s.svc.ReportFeedback(ctx, uid, videoID, "read", time.Now())
    }
    return nil
}

func (s *useCase) IncrementLikeCount(ctx context.Context, videoID int64) error {
    if err := s.db.IncrementLikeCount(ctx, videoID); err != nil {
        return err
    }
    if uid, err := pkgcontext.GetUserID(ctx); err == nil && uid > 0 {
        s.svc.ReportFeedback(ctx, uid, videoID, "like", time.Now())
    }
    return nil
}

func (s *useCase) SemanticSearch(
	ctx context.Context,
	query string,
	pageSize, pageNum int32,
	threshold float64,
) ([]*model.SemanticSearchResultItem, error) {
	result, err := s.svc.Search(ctx, query, pageSize)
	if err != nil {
		return nil, err
	}

	var res []*model.SemanticSearchResultItem
	for _, video := range result.Videos {
		video, err := s.GetVideoDetail(ctx, video.ID, 0)
		if err != nil {
			return nil, err
		}
		// 转换 Video 到 SemanticSearchResultItem
		item := &model.SemanticSearchResultItem{
			Videos:         []*model.Video{video},
			Summary:        result.Summary,
			RelatedQueries: result.RelatedQueries,
			FromCache:      result.FromCache,
		}
		res = append(res, item)
	}
	return res, nil
}

func (s *useCase) UploadCover(ctx context.Context, videoID int64, coverData []byte, contentType string) (string, error) {
	return s.svc.UploadCover(ctx, videoID, coverData, contentType)
}
