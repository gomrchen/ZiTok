package pack

import (
	"fmt"

	"github.com/mutezebra/tiktok/app/video/config"
	video "github.com/mutezebra/tiktok/app/video/domain/service"
	"github.com/mutezebra/tiktok/app/video/interface/persistence/cache"
	"github.com/mutezebra/tiktok/app/video/interface/persistence/database"
	"github.com/mutezebra/tiktok/app/video/usecase"
	"github.com/mutezebra/tiktok/pkg/constants"
	"github.com/mutezebra/tiktok/pkg/inject"
	"github.com/mutezebra/tiktok/pkg/oss"
	"github.com/mutezebra/tiktok/pkg/snowflake"
)

func VideoRegistry() *inject.Registry {
	id := snowflake.GenerateID(config.Conf.System.WorkerID, config.Conf.System.DataCenterID)
	return &inject.Registry{
		Addr:     config.Conf.Service[constants.VideoServiceName].SvcAddress,
		Key:      config.Conf.Service[constants.VideoServiceName].ServiceName + fmt.Sprintf("/%d", id),
		Prefix:   config.Conf.Etcd.ServicePrefix,
		EndPoint: config.Conf.Etcd.Endpoint,
	}
}

func ApplyVideo() *usecase.VideoCase {
	repo := database.NewVideoRepository()
	ossModel := oss.NewOssModel(config.Conf.QiNiu.AvatarPath, config.Conf.QiNiu.VideoPath, config.Conf.QiNiu.CoverPath)
	cacheRepo := cache.NewVideoCacheRepo()
	service := &video.Service{
		EnablePopularVideoRank:  true,
		EnableTimedRefreshViews: true,
		Repo:                    repo,
		Cache:                   cacheRepo,
		Oss:                     ossModel,
	}
	return usecase.NewVideoUseCase(repo, cacheRepo, video.NewService(service))
}
