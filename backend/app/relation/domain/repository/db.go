package repository

import "context"

type RelationRepository interface {
	Follow(ctx context.Context, uid, followerID int64) error
	WhetherFollowExist(ctx context.Context, uid, followerID int64) (bool, error)
	GetFollowList(ctx context.Context, uid int64) ([]int64, error)
	GetFansList(ctx context.Context, uid int64) ([]int64, error)
	GetFriendList(ctx context.Context, uid int64) ([]int64, error)
	WhetherUserExist(ctx context.Context, uid int64) bool
}
