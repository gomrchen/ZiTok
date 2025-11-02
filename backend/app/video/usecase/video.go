package usecase

import (
	"context"
	"fmt"
	"path/filepath"
	"strconv"
	"time"

	"github.com/mutezebra/tiktok/app/video/domain/model"
	"github.com/mutezebra/tiktok/app/video/domain/repository"
	videoService "github.com/mutezebra/tiktok/app/video/domain/service"
	"github.com/mutezebra/tiktok/app/video/usecase/pack"
	"github.com/mutezebra/tiktok/pkg/constants"
	"github.com/mutezebra/tiktok/pkg/kitex_gen/api/video"
)

type VideoCase struct {
	repo    repository.VideoRepository
	cache   repository.VideoCacheRepository
	service *videoService.Service
}

func NewVideoUseCase(repo repository.VideoRepository, cache repository.VideoCacheRepository, service *videoService.Service) *VideoCase {
	return &VideoCase{
		repo:    repo,
		cache:   cache,
		service: service,
	}
}

type dtoVideo struct {
	vid      int64
	uid      int64
	videoURL string
	coverURL string
	intro    string
	title    string
	videoExt string
	coverExt string
}

func (v *VideoCase) VideoFeed(req *video.VideoFeedReq, stream video.VideoService_VideoFeedServer) (err error) {
	err = v.service.IncrViews(context.Background(), req.GetVID())
	if err != nil {
		return pack.ReturnError(model.IncrViewError, err)
	}

	videoName, err := v.service.OssVideoName(context.Background(), req.GetVID())
	if err != nil {
		return pack.ReturnError(model.OssGetVideoFeedError, err)
	}

	data, err := v.service.VideoFeed(videoName)
	if err != nil {
		return pack.ReturnError(model.OssGetVideoFeedError, err)
	}

	resp := new(video.VideoFeedResp)
	begin := 0
	offset := 2 * constants.MB
	remain := len(data)
	for remain > 0 {
		if remain < offset {
			resp.Video = data[begin:]
		} else {
			resp.Video = data[begin : begin+offset]
			begin += offset
		}
		remain -= offset
		err = stream.Send(resp)
		if err != nil {
			return pack.ReturnError(model.VideoFeedStreamSendError, err)
		}
	}

	return nil
}

func (v *VideoCase) PublishVideo(ctx context.Context, req *video.PublishVideoReq) (r *video.PublishVideoResp, err error) {
	vid := v.service.GenerateID()
	videoExt := filepath.Ext(req.GetVideoName())
	videoName := fmt.Sprintf("%d%s", vid, videoExt)
	err, videoURL := v.service.UploadVideo(ctx, videoName, req.GetVideo())
	if err != nil {
		return nil, pack.ReturnError(model.OssUploadVideoError, err)
	}

	coverExt := filepath.Ext(req.GetCoverName())
	coverName := fmt.Sprintf("%d%s", vid, coverExt)
	err, coverURL := v.service.UploadVideoCover(ctx, coverName, req.GetCover())
	if err != nil {
		return nil, pack.ReturnError(model.OssUploadVideoCoverError, err)
	}

	dto := &dtoVideo{
		vid:      vid,
		uid:      req.GetUID(),
		videoURL: videoURL,
		coverURL: coverURL,
		videoExt: videoExt,
		coverExt: coverExt,
		intro:    req.GetIntro(),
		title:    req.GetTitle(),
	}

	vid, err = v.repo.CreateVideo(ctx, dtoV2Repo(dto))
	if err != nil {
		return nil, pack.ReturnError(model.DatabaseCreateVideoError, err)
	}

	r = new(video.PublishVideoResp)
	strVid := strconv.FormatInt(vid, 10)
	r.SetVID(&strVid)

	return r, nil
}

func (v *VideoCase) GetVideoList(ctx context.Context, req *video.GetVideoListReq) (r *video.GetVideoListResp, err error) {
	videos, err := v.repo.GetVideoListByID(ctx, req.GetUID(), int(req.GetPages()), int(req.GetSize()))
	if err != nil {
		return nil, pack.ReturnError(model.DatabaseGetVideoListError, err)
	}

	respVideos := make([]*video.VideoInfo, len(videos))
	for i := range videos {
		respVideos[i] = repoV2IDL(&videos[i])
	}

	r = new(video.GetVideoListResp)
	length := int32(len(videos))
	r.SetCount(&length)
	r.SetItems(respVideos)
	return r, err
}

func (v *VideoCase) GetVideoPopular(ctx context.Context, req *video.GetVideoPopularReq) (r *video.GetVideoPopularResp, err error) {
	vids := v.cache.GetPopularVids()
	videos, err := v.repo.GetVideosInfo(ctx, vids)
	if err != nil {
		return nil, pack.ReturnError(model.DatabaseGetVideoInfoError, err)
	}
	r = new(video.GetVideoPopularResp)
	length := int32(len(vids))
	r.SetCount(&length)
	r.Items = make([]*video.VideoInfo, 0, length)
	for i := range videos {
		r.Items = append(r.Items, repoV2IDL(&videos[i]))
	}
	return r, nil
}

func (v *VideoCase) SearchVideo(ctx context.Context, req *video.SearchVideoReq) (r *video.SearchVideoResp, err error) {
	videos, err := v.repo.SearchVideo(ctx, req.GetContent(), int(req.GetPages()), int(req.GetSize()))

	respVideos := make([]*video.VideoInfo, len(videos))
	for i := range videos {
		respVideos[i] = repoV2IDL(&videos[i])
	}

	r = new(video.SearchVideoResp)
	length := int32(len(videos))
	r.SetCount(&length)
	r.SetItems(respVideos)
	return r, err
}

func dtoV2Repo(dto *dtoVideo) *repository.Video {
	return &repository.Video{
		ID:       dto.vid,
		UID:      dto.uid,
		VideoURL: dto.videoURL,
		CoverURL: dto.coverURL,
		Intro:    dto.intro,
		Title:    dto.title,
		VideoExt: dto.videoExt,
		CoverExt: dto.coverExt,
		CreateAt: time.Now().Unix(),
		UpdateAt: time.Now().Unix(),
	}
}

func repoV2IDL(repo *repository.Video) *video.VideoInfo {
	vid := strconv.FormatInt(repo.ID, 10)
	uid := strconv.FormatInt(repo.UID, 10)
	return &video.VideoInfo{
		ID:       &vid,
		UID:      &uid,
		VideoURL: &repo.VideoURL,
		CoverURL: &repo.CoverURL,
		Intro:    &repo.Intro,
		Title:    &repo.Title,
		Starts:   &repo.Starts,
		Likes:    &repo.Likes,
		Views:    &repo.Views,
	}
}
