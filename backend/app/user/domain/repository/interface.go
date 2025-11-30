package repository

import (
	"context"

	"github.com/yxrxy/videoHub/app/user/domain/model"
)

type UserDB interface {
	IsUserExist(ctx context.Context, username string) (bool, error)
	IsUserExistByID(ctx context.Context, id int64) (bool, error)
	CreateUser(ctx context.Context, user *model.User) (int64, error)
	GetUserInfo(ctx context.Context, username string) (*model.User, error)
	GetUserByID(ctx context.Context, id int64) (*model.User, error)
	UpdateUser(ctx context.Context, user *model.User) error
	UpdateAvatar(ctx context.Context, user *model.User) error
	UpdateBackground(ctx context.Context, user *model.User) error
	FindUserByEmail(ctx context.Context, email string) (int64, error)
	FindUsersByUsername(ctx context.Context, username string) ([]*model.User, error)

	// --- 收藏相关方法 ---
	FavoriteVideo(ctx context.Context, userID, videoID int64) error
	UnfavoriteVideo(ctx context.Context, userID, videoID int64) error
	GetFavoriteVideos(ctx context.Context, userID int64, page, size int) ([]int64, int64, error)
	IsVideoFavorited(ctx context.Context, userID, videoID int64) (bool, error)
}

type UserCache interface {
	IsExist(ctx context.Context, key string) bool
	SetUserAccessToken(ctx context.Context, key string, token string) error
	SetUserRefreshToken(ctx context.Context, key string, token string) error
	DeleteUserToken(ctx context.Context, key string) error
	GetToken(ctx context.Context, key string) (string, error)
}
