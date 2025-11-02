package video

import (
	"context"
	"fmt"
	"path/filepath"
	"strings"
	"time"

	"github.com/mutezebra/tiktok/app/video/config"
	"github.com/mutezebra/tiktok/app/video/domain/model"
	"github.com/mutezebra/tiktok/app/video/domain/repository"
	"github.com/mutezebra/tiktok/pkg/constants"
	"github.com/mutezebra/tiktok/pkg/log"
	"github.com/mutezebra/tiktok/pkg/snowflake"
)

type Service struct {
	EnablePopularVideoRank  bool
	EnableTimedRefreshViews bool

	Repo  repository.VideoRepository
	Cache repository.VideoCacheRepository
	Oss   model.OSS
}

func NewService(service *Service) *Service {
	if service.Repo == nil {
		log.LogrusObj.Panic("video service.Repo should not be nil")
	}
	if service.Cache == nil {
		log.LogrusObj.Panic("video service.cacheRepo should not be nil")
	}
	if service.Oss == nil {
		log.LogrusObj.Panic("video service.OSS should not be nil")
	}
	if service.EnablePopularVideoRank {
		service.Cache.EnablePopularRanking()
	}
	if service.EnableTimedRefreshViews {
		service.timedRefreshViews()
	}
	return service
}

func (s *Service) IsVideo(filename string) bool {
	ext := filepath.Ext(filename)
	imageExts := []string{".mp4", ".avi", ".mov"}
	for _, imageExt := range imageExts {
		if strings.EqualFold(ext, imageExt) {
			return true
		}
	}
	return false
}

func (s *Service) IsImage(filename string) bool {
	ext := filepath.Ext(filename)
	imageExts := []string{".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp", ".tiff"}
	for _, imageExt := range imageExts {
		if strings.EqualFold(ext, imageExt) {
			return true
		}
	}
	return false
}

func (s *Service) GenerateID() int64 {
	return snowflake.GenerateID(config.Conf.System.WorkerID, config.Conf.System.DataCenterID)
}

func (s *Service) UploadVideo(ctx context.Context, name string, data []byte) (err error, url string) {
	err, path := s.Oss.UploadVideo(ctx, name, data)
	if err != nil {
		return err, path
	}
	url = s.Oss.DownloadVideo(ctx, path)
	return nil, url
}

func (s *Service) UploadVideoCover(ctx context.Context, name string, data []byte) (err error, url string) {
	err, path := s.Oss.UploadVideoCover(ctx, name, data)
	if err != nil {
		return err, path
	}
	url = s.Oss.DownloadVideoCover(ctx, path)
	return nil, url
}

func (s *Service) OssVideoURL(ctx context.Context, vid int64) (string, error) {
	val, err := s.Repo.GetValByColumn(ctx, vid, "video_url")
	if err != nil {
		return "", err
	}

	return val, nil
}

func (s *Service) OssCoverURL(ctx context.Context, vid int64) (string, error) {
	val, err := s.Repo.GetValByColumn(ctx, vid, "cover_url")
	if err != nil {
		return "", err
	}

	return val, nil
}

func (s *Service) OssVideoName(ctx context.Context, vid int64) (string, error) {
	val, err := s.Repo.GetValByColumn(ctx, vid, "video_ext")
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%d%s", vid, val), nil
}

func (s *Service) OssCoverName(ctx context.Context, vid int64) (string, error) {
	val, err := s.Repo.GetValByColumn(ctx, vid, "cover_ext")
	if err != nil {
		return "", err
	}

	return fmt.Sprintf("%d%s", vid, val), nil
}

func (s *Service) VideoFeed(name string) ([]byte, error) {
	return s.Oss.VideoFeed(name)
}

func (s *Service) IncrViews(ctx context.Context, vid int64) error {
	if s.Cache.ViewKeyExist(vid) {
		return s.Cache.IncrVideoViews(vid)
	}

	views, err := s.Repo.GetVideoViews(ctx, vid)
	if err != nil {
		return err
	}
	return s.Cache.SetVideoViews(vid, views)
}

func (s *Service) timedRefreshViews(intervals ...time.Duration) {
	var interval time.Duration
	if intervals == nil {
		interval = constants.DatabaseDefaultUpdateViewInterval
	} else {
		interval = intervals[0]
	}

	go func(s *Service, interval time.Duration) {
		for {
			kvs := s.Cache.ViewsKVS()
			if kvs != nil {
				s.Repo.UpdateViews(kvs)
			}
			time.Sleep(interval)
		}
	}(s, interval)
}
