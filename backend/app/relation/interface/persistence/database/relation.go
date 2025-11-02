package database

import (
	"context"
	"database/sql"

	"github.com/pkg/errors"
)

type RelationRepository struct {
	db *sql.DB
}

func NewRelationRepository() *RelationRepository {
	return &RelationRepository{_db}
}

func (repo *RelationRepository) WhetherFollowExist(ctx context.Context, uid, followerID int64) (bool, error) {
	var exist bool
	err := repo.db.QueryRowContext(ctx, "SELECT EXISTS(SELECT 1 FROM follow_table WHERE user_id=? AND follow_id=?)", uid, followerID).Scan(&exist)
	if err != nil {
		return exist, errors.Wrap(err, "check follow exist failed")
	}

	return exist, nil
}

// Follow uid follows followerID
func (repo *RelationRepository) Follow(ctx context.Context, uid, followerID int64) error {
	_, err := repo.db.ExecContext(ctx, "INSERT INTO follow_table(user_id, follow_id) VALUES (?,?)", uid, followerID)
	if err != nil {
		return errors.Wrap(err, "insert to follow failed")
	}

	_, err = repo.db.ExecContext(ctx, "UPDATE user SET follows = follows + 1 WHERE id=?", uid)
	if err != nil {
		return errors.Wrap(err, "update user follows failed")
	}

	_, err = repo.db.ExecContext(ctx, "UPDATE user SET fans = fans + 1 WHERE id=?", followerID)
	if err != nil {
		return errors.Wrap(err, "update user fans failed")
	}

	return nil
}

func (repo *RelationRepository) GetFollowList(ctx context.Context, uid int64) ([]int64, error) {
	rows, err := repo.db.QueryContext(ctx, "SELECT follow_id FROM follow_table WHERE user_id=?", uid)
	if err != nil {
		return nil, errors.Wrap(err, "get follow list failed")
	}
	defer func() {
		if err = rows.Close(); err != nil {
			err = errors.Wrap(err, "close rows failed")
		}
	}()

	var ids []int64
	for rows.Next() {
		var id int64
		err = rows.Scan(&id)
		if err != nil {
			return nil, errors.Wrap(err, "scan follow list failed")
		}
		ids = append(ids, id)
	}

	return ids, nil
}

func (repo *RelationRepository) GetFansList(ctx context.Context, uid int64) ([]int64, error) {
	rows, err := repo.db.QueryContext(ctx, "SELECT user_id FROM follow_table WHERE follow_id=?", uid)
	if err != nil {
		return nil, errors.Wrap(err, "get fans list failed")
	}
	defer func() {
		if err = rows.Close(); err != nil {
			err = errors.Wrap(err, "close rows failed")
		}
	}()

	var ids []int64
	for rows.Next() {
		var id int64
		err = rows.Scan(&id)
		if err != nil {
			return nil, errors.Wrap(err, "scan fans list failed")
		}
		ids = append(ids, id)
	}

	return ids, nil
}

func (repo *RelationRepository) GetFriendList(ctx context.Context, uid int64) ([]int64, error) {
	followList, err := repo.GetFollowList(ctx, uid)
	if err != nil {
		return nil, err
	}
	fansList, err := repo.GetFansList(ctx, uid)
	if err != nil {
		return nil, err
	}

	var ids []int64
	for _, id := range followList {
		for _, fid := range fansList {
			if id == fid {
				ids = append(ids, id)
			}
		}
	}

	return ids, nil
}

func (repo *RelationRepository) WhetherUserExist(ctx context.Context, uid int64) bool {
	var exist bool
	err := repo.db.QueryRowContext(ctx, "SELECT EXISTS(SELECT 1 FROM user WHERE id=?)", uid).Scan(&exist)
	if err != nil {
		return false
	}

	return exist
}
