package database

import (
	"context"
	"database/sql"

	"github.com/mutezebra/tiktok/app/user/domain/repository"

	"github.com/pkg/errors"

	_ "github.com/go-sql-driver/mysql"
)

type UserRepository struct {
	db *sql.DB
}

func NewUserRepository() *UserRepository {
	return &UserRepository{_db}
}

// CreateUser create a repository.User object in database.
func (repo *UserRepository) CreateUser(ctx context.Context, user *repository.User) error {
	_, err := repo.db.ExecContext(ctx,
		"INSERT INTO user(id,user_name,email,password_digest,gender,avatar,fans,follows,totp_enable,totp_secret,create_at,update_at,delete_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?) ",
		user.ID, user.UserName, user.Email, user.PasswordDigest,
		user.Gender, user.Avatar, user.Fans, user.Follows,
		user.TotpEnable, user.TotpSecret, user.CreateAt, user.UpdateAt,
		user.DeleteAt)
	if err != nil {
		return errors.Wrap(err, "insert item to user failed")
	}
	return nil
}

// UserNameExists checks if a username already exists in the database.
func (repo *UserRepository) UserNameExists(ctx context.Context, userName string) (bool, error) {
	var exists bool
	query := "SELECT EXISTS(SELECT 1 FROM user WHERE user_name=?)"
	err := repo.db.QueryRowContext(ctx, query, userName).Scan(&exists)
	if err != nil {
		return false, errors.Wrap(err, "query user by name failed")
	}
	return exists, nil
}

func (repo *UserRepository) GetPasswordAndIDByName(ctx context.Context, name string) (string, int64, error) {
	var passwordDigest string
	var id int64
	if err := repo.db.QueryRowContext(ctx, "SELECT password_digest,id from user WHERE user_name=? LIMIT 1", name).Scan(
		&passwordDigest, &id); err != nil {
		return "", 0, errors.Wrap(err, "query password and id by name failed")
	}

	return passwordDigest, id, nil
}

// UserInfoByID retrieves a user's information from the database using the user's ID.
func (repo *UserRepository) UserInfoByID(ctx context.Context, id int64) (*repository.User, error) {
	var user repository.User
	if err := repo.db.QueryRowContext(ctx, "SELECT * from user WHERE id=? LIMIT 1", id).Scan(
		&user.ID, &user.UserName, &user.Email, &user.PasswordDigest,
		&user.Gender, &user.Avatar, &user.Fans, &user.Follows,
		&user.TotpEnable, &user.TotpSecret, &user.CreateAt, &user.UpdateAt,
		&user.DeleteAt); err != nil {
		return nil, errors.Wrap(err, "query user by id failed")
	}

	return &user, nil
}

// UserInfoByName retrieves a user's information from the database using the user's ID.
func (repo *UserRepository) UserInfoByName(ctx context.Context, name string) (*repository.User, error) {
	var user repository.User
	if err := repo.db.QueryRowContext(ctx, "SELECT * from user WHERE user_name=? LIMIT 1", name).Scan(
		&user.ID, &user.UserName, &user.Email, &user.PasswordDigest,
		&user.Gender, &user.Avatar, &user.Fans, &user.Follows,
		&user.TotpEnable, &user.TotpSecret, &user.CreateAt, &user.UpdateAt,
		&user.DeleteAt); err != nil {
		return nil, errors.Wrap(err, "query user by name failed")
	}

	return &user, nil
}

func (repo *UserRepository) UpdateUserAvatar(ctx context.Context, filename string, uid int64) error {
	_, err := repo.db.ExecContext(ctx, "UPDATE user SET avatar=? WHERE id=?", filename, uid)
	if err != nil {
		return errors.Wrap(err, "update user avatar failed")
	}
	return nil
}

func (repo *UserRepository) GetUserAvatar(ctx context.Context, uid int64) (string, error) {
	var url string
	err := repo.db.QueryRowContext(ctx, "SELECT avatar FROM user WHERE id=?", uid).Scan(&url)
	if err != nil {
		return "", errors.Wrap(err, "query user avatar failed")
	}
	return url, nil
}

func (repo *UserRepository) UpdateTotpSecret(ctx context.Context, uid int64, secret string) error {
	_, err := repo.db.ExecContext(ctx, "UPDATE user SET totp_secret=? WHERE id=?", secret, uid)
	if err != nil {
		return errors.Wrap(err, "update totp secret failed")
	}
	return nil
}

func (repo *UserRepository) GetTotpSecret(ctx context.Context, uid int64) (string, error) {
	var secret string
	err := repo.db.QueryRowContext(ctx, "SELECT totp_secret FROM user WHERE id=?", uid).Scan(&secret)
	if err != nil {
		return "", errors.Wrap(err, "query totp secret failed")
	}
	return secret, nil
}

func (repo *UserRepository) UpdateTotpStatus(ctx context.Context, status bool, uid int64) error {
	_, err := repo.db.ExecContext(ctx, "UPDATE user SET totp_enable=? WHERE id=?", status, uid)
	if err != nil {
		return errors.Wrap(err, "update totp status failed")
	}
	return nil
}

func (repo *UserRepository) UpdateColumnByKV(ctx context.Context, uid int64, k, v string) error {
	_, err := repo.db.ExecContext(ctx, "UPDATE user SET ?=? WHERE id=?", k, v, uid)
	if err != nil {
		return errors.Wrap(err, "update column by kv failed")
	}
	return nil
}

func (repo *UserRepository) GetColumnByKUID(ctx context.Context, key string, uid int64) (string, error) {
	var value string
	err := repo.db.QueryRowContext(ctx, "SELECT ? FROM user WHERE id=?", key, uid).Scan(&value)
	if err != nil {
		return "", errors.Wrap(err, "get column by kuid failed")
	}
	return value, nil
}
