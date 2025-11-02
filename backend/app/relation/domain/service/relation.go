package relation

import (
	"context"

	"github.com/pkg/errors"

	"github.com/mutezebra/tiktok/app/relation/domain/repository"
)

type Service struct {
	repo repository.RelationRepository
}

func NewService(repo repository.RelationRepository) *Service {
	return &Service{repo: repo}
}

func (s *Service) CheckNameLength(name string) error {
	if len(name) > 20 {
		return errors.New("name too long")
	}
	return nil
}

func (s *Service) CheckUserExist(ctx context.Context, uid int64) error {
	exist := s.repo.WhetherUserExist(ctx, uid)
	if !exist {
		return errors.New("user not exist")
	}
	return nil
}
