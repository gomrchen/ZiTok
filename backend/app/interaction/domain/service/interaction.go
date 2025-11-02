package interaction

import (
	"github.com/mutezebra/tiktok/app/interaction/config"
	"github.com/mutezebra/tiktok/app/interaction/domain/repository"
	"github.com/mutezebra/tiktok/pkg/snowflake"
)

type Service struct {
	Repo repository.InteractionRepository
}

func NewService(service *Service) *Service {
	if service.Repo == nil {
		panic("interaction service.repo should not be nil")
	}
	return service
}

func (srv *Service) GenerateID() int64 {
	return snowflake.GenerateID(config.Conf.System.WorkerID, config.Conf.System.DataCenterID)
}
