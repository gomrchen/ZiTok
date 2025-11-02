package repository

import (
	"context"

	"github.com/mutezebra/tiktok/pkg/types"
)

type User types.User

// UserRepository defines the operational
// criteria for the user repository
type UserRepository interface {
	CreateUser(ctx context.Context, user *User) error // create a new user
	UserNameExists(ctx context.Context, userName string) (bool, error)
	GetPasswordAndIDByName(ctx context.Context, name string) (string, int64, error)
	UserInfoByID(ctx context.Context, id int64) (*User, error)
	UserInfoByName(ctx context.Context, name string) (*User, error)
	UpdateUserAvatar(ctx context.Context, filename string, uid int64) error
	GetUserAvatar(ctx context.Context, uid int64) (string, error)
	UpdateTotpSecret(ctx context.Context, uid int64, secret string) error
	GetTotpSecret(ctx context.Context, uid int64) (string, error)
	UpdateTotpStatus(ctx context.Context, status bool, uid int64) error
	UpdateColumnByKV(ctx context.Context, uid int64, k, v string) error
	GetColumnByKUID(ctx context.Context, key string, uid int64) (string, error)
}
