package pack

import (
	"fmt"

	"github.com/mutezebra/tiktok/app/user/config"
	user "github.com/mutezebra/tiktok/app/user/domain/service"
	"github.com/mutezebra/tiktok/app/user/interface/persistence/database"
	"github.com/mutezebra/tiktok/app/user/usecase"
	"github.com/mutezebra/tiktok/pkg/constants"
	"github.com/mutezebra/tiktok/pkg/inject"
	"github.com/mutezebra/tiktok/pkg/log"
	"github.com/mutezebra/tiktok/pkg/oss"
	"github.com/mutezebra/tiktok/pkg/snowflake"
	"github.com/mutezebra/tiktok/pkg/utils"
)

func UserRegistry() *inject.Registry {
	id := snowflake.GenerateID(config.Conf.System.WorkerID, config.Conf.System.DataCenterID)
	return &inject.Registry{
		Addr:     config.Conf.Service[constants.UserServiceName].SvcAddress,
		Key:      config.Conf.Service[constants.UserServiceName].ServiceName + fmt.Sprintf("/%d", id),
		Prefix:   config.Conf.Etcd.ServicePrefix,
		EndPoint: config.Conf.Etcd.Endpoint,
	}
}

func ApplyUser() *usecase.UserCase {
	conf := config.Conf
	repo := database.NewUserRepository()
	ossModel := oss.NewOssModel(conf.QiNiu.AvatarPath, conf.QiNiu.VideoPath, conf.QiNiu.CoverPath)
	mfaModel := utils.NewMFAModel()
	resolver, err := inject.NewResolver(conf.Etcd.Endpoint)
	if err != nil {
		log.LogrusObj.Panic(err)
	}

	service := &user.Service{
		Repo:     repo,
		MFA:      mfaModel,
		OSS:      ossModel,
		Resolver: resolver,
	}

	return usecase.NewUserUseCase(repo, user.NewService(service))
}
