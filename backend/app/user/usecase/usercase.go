package usecase

import (
	"context"

	"github.com/yxrxy/videoHub/app/user/domain/model"
	"github.com/yxrxy/videoHub/app/user/domain/repository"
	"github.com/yxrxy/videoHub/app/user/domain/service"
)

// UserUseCase 接口应该不应该定义在 domain 中，这属于 use case 层
type UserUseCase interface {
	Register(ctx context.Context, user *model.User) (uid int64, err error)
	Login(ctx context.Context, user *model.User) (*model.User, error)
	GetUserInfo(ctx context.Context, uid int64) (*model.User, error)
	UpdateUserInfo(ctx context.Context, uid int64, user *model.User) error
	UploadAvatar(ctx context.Context, uid int64, avatarData []byte, contentType string) (*model.User, error)
	RefreshToken(ctx context.Context, uid int64, refreshToken string) (string, string, error)
	UploadBackground(ctx context.Context, uid int64, backgroundData []byte, contentType string) (*model.User, error)
	FindUserByEmail(ctx context.Context, email string) (int64, error)
	FindUsersByUsername(ctx context.Context, username string) ([]*model.User, error)

	// --- 收藏相关方法 ---
	FavoriteVideo(ctx context.Context, uid int64, videoID int64) error
	UnfavoriteVideo(ctx context.Context, uid int64, videoID int64) error
	GetFavoriteVideos(ctx context.Context, uid int64, page, size int) ([]int64, int64, error)
}

type useCase struct {
	db  repository.UserDB
	svc *service.UserService
}

func NewUserCase(db repository.UserDB, svc *service.UserService) *useCase {
	return &useCase{
		db:  db,
		svc: svc,
	}
}
