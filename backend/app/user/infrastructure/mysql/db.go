package mysql

import (
	"context"
	"crypto/md5"
	"errors"
	"fmt"
	"time"

	"github.com/yxrxy/videoHub/app/user/domain/model"
	"github.com/yxrxy/videoHub/app/user/domain/repository"
	"github.com/yxrxy/videoHub/pkg/errno"
	"gorm.io/gorm"
)

type userDB struct {
	db *gorm.DB
}

func NewUserDB(db *gorm.DB) repository.UserDB {
	return &userDB{db: db}
}

func (u *userDB) IsUserExist(ctx context.Context, username string) (bool, error) {
	var count int64
	if err := u.db.WithContext(ctx).Model(&User{}).
		Where("username = ?", username).Count(&count).Error; err != nil {
		return false, err
	}
	return count > 0, nil
}

// IsUserExistByID 检查用户是否存在
func (u *userDB) IsUserExistByID(ctx context.Context, id int64) (bool, error) {
	var count int64
	if err := u.db.WithContext(ctx).Model(&User{}).
		Where("id = ?", id).Count(&count).Error; err != nil {
		return false, err
	}
	return count > 0, nil
}

func (u *userDB) CreateUser(ctx context.Context, user *model.User) (int64, error) {
	// 将 domain model 转换为 DB model
	dbUser := &User{
		Username:  user.Username,
		Password:  user.Password,
		AvatarURL: user.AvatarURL,
		Status:    int8(0),
		Email:     user.Email,
	}
	if err := u.db.WithContext(ctx).Create(dbUser).Error; err != nil {
		return 0, err
	}
	return dbUser.ID, nil
}

func packUser(u *User) *model.User {
	if u == nil {
		return nil
	}

	// 处理生日格式转换
	var birthdayStr string
	if u.Birthday != nil {
		birthdayStr = u.Birthday.Format("2006-01-02")
	}

	return &model.User{
		ID:            u.ID,
		Username:      u.Username,
		Password:      u.Password,
		Email:         u.Email, // 新增
		AvatarURL:     u.AvatarURL,
		BackgroundURL: u.BackgroundURL, // 新增
		Signature:     u.Signature,     // 新增
		Gender:        int64(u.Gender), // 新增 (注意类型转换，model如果是int64)
		Birthday:      birthdayStr,     // 新增
		Status:        int64(u.Status), // 新增
		// CreatedAt/UpdatedAt 如果 domain model 需要也可以加上
	}
}

func (u *userDB) GetUserInfo(ctx context.Context, username string) (*model.User, error) {
	var user User
	if err := u.db.WithContext(ctx).Where("username = ?", username).First(&user).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errno.NewErrNo(errno.ParamVerifyErrorCode, "user not exist")
		}
		return nil, err
	}
	return packUser(&user), nil
}

func (u *userDB) GetUserByID(ctx context.Context, id int64) (*model.User, error) {
	var user User
	if err := u.db.WithContext(ctx).First(&user, id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errno.NewErrNo(errno.ParamVerifyErrorCode, "user not exist")
		}
		return nil, err
	}
	return packUser(&user), nil
}

func (u *userDB) UpdateUser(ctx context.Context, user *model.User) error {
	updates := map[string]interface{}{}

	// 只有非空值才更新，或者根据业务需求调整
	if user.AvatarURL != "" {
		updates["avatar_url"] = user.AvatarURL
	}
	// 用户名不能为空
	if user.Username != "" {
		updates["username"] = user.Username
	}
	// 密码需要进行哈希处理
	if user.Password != "" {
		// 对密码进行MD5哈希处理
		hashedPassword := fmt.Sprintf("%x", md5.Sum([]byte(user.Password)))
		updates["password"] = hashedPassword
	}

	// 新增字段更新逻辑
	if user.Email != "" {
		updates["email"] = user.Email
	}
	if user.BackgroundURL != "" {
		updates["background_url"] = user.BackgroundURL
	}
	if user.Signature != "" {
		updates["signature"] = user.Signature
	}
	if user.Gender != 0 { // 假设0是无效值/未知，具体看业务定义
		updates["gender"] = user.Gender
	}
	if user.Birthday != "" { // 假设 domain model 中生日是 string "YYYY-MM-DD"
		// 需要解析为 time.Time
		t, err := time.Parse("2006-01-02", user.Birthday)
		if err == nil {
			updates["birthday"] = t
		}
	}
	
	if len(updates) == 0 {
		return nil
	}
	return u.db.WithContext(ctx).Model(&User{}).Where("id = ?", user.ID).
		Updates(updates).Error
}

// UpdateAvatar 专用方法，只更新头像（保留旧方法）
func (u *userDB) UpdateAvatar(ctx context.Context, user *model.User) error {
	return u.db.WithContext(ctx).Model(&User{}).Where("id = ?", user.ID).
		Update("avatar_url", user.AvatarURL).Error
}

// UpdateBackground 专用方法，只更新背景图 (新增)
func (u *userDB) UpdateBackground(ctx context.Context, user *model.User) error {
	return u.db.WithContext(ctx).Model(&User{}).Where("id = ?", user.ID).
		Update("background_url", user.BackgroundURL).Error
}

func (u *userDB) ExistByUsername(ctx context.Context, username string) (bool, error) {
	var count int64
	if err := u.db.WithContext(ctx).Model(&User{}).
		Where("username = ?", username).Count(&count).Error; err != nil {
		return false, err
	}
	return count > 0, nil
}

// FindUserByEmail 根据邮箱查找用户
func (u *userDB) FindUserByEmail(ctx context.Context, email string) (int64, error) {
	var user User
	if err := u.db.WithContext(ctx).Where("email = ?", email).First(&user).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return 0, errno.NewErrNo(errno.ServiceUserNotExist, "user not exist")
		}
		return 0, err
	}
	return user.ID, nil
}

// FindUsersByUsername 根据用户名模糊匹配查找用户
func (u *userDB) FindUsersByUsername(ctx context.Context, username string) ([]*model.User, error) {
	var users []User
	if err := u.db.WithContext(ctx).Where("username LIKE ?", "%"+username+"%").
		Select("id, username, avatar_url").Find(&users).Error; err != nil {
		return nil, err
	}

	result := make([]*model.User, len(users))
	for i, user := range users {
		result[i] = &model.User{
			ID:        user.ID,
			Username:  user.Username,
			AvatarURL: user.AvatarURL,
		}
	}
	return result, nil
}

// --- 收藏相关方法 ---

// FavoriteVideo 收藏视频
func (u *userDB) FavoriteVideo(ctx context.Context, userID, videoID int64) error {
	// 检查是否已经收藏
	var count int64
	if err := u.db.WithContext(ctx).Model(&Favorite{}).
		Where("user_id = ? AND video_id = ? AND deleted_at IS NULL", userID, videoID).
		Count(&count).Error; err != nil {
		return err
	}

	// 如果已经收藏，直接返回
	if count > 0 {
		return nil
	}

	// 创建新的收藏记录
	favorite := &Favorite{
		UserID:  userID,
		VideoID: videoID,
	}
	return u.db.WithContext(ctx).Create(favorite).Error
}

// UnfavoriteVideo 取消收藏视频
func (u *userDB) UnfavoriteVideo(ctx context.Context, userID, videoID int64) error {
	return u.db.WithContext(ctx).
		Where("user_id = ? AND video_id = ? AND deleted_at IS NULL", userID, videoID).
		Delete(&Favorite{}).Error
}

// GetFavoriteVideos 获取用户收藏的视频ID列表
func (u *userDB) GetFavoriteVideos(ctx context.Context, userID int64, page, size int) ([]int64, int64, error) {
	var favorites []Favorite
	var total int64

	// 获取总数
	if err := u.db.WithContext(ctx).Model(&Favorite{}).
		Where("user_id = ? AND deleted_at IS NULL", userID).
		Count(&total).Error; err != nil {
		return nil, 0, err
	}

	// 获取分页数据
	offset := (page - 1) * size
	if err := u.db.WithContext(ctx).
		Where("user_id = ? AND deleted_at IS NULL", userID).
		Offset(offset).Limit(size).
		Find(&favorites).Error; err != nil {
		return nil, 0, err
	}

	// 提取视频ID
	videoIDs := make([]int64, len(favorites))
	for i, favorite := range favorites {
		videoIDs[i] = favorite.VideoID
	}

	return videoIDs, total, nil
}

// IsVideoFavorited 检查用户是否已收藏某个视频
func (u *userDB) IsVideoFavorited(ctx context.Context, userID, videoID int64) (bool, error) {
	var count int64
	if err := u.db.WithContext(ctx).Model(&Favorite{}).
		Where("user_id = ? AND video_id = ? AND deleted_at IS NULL", userID, videoID).
		Count(&count).Error; err != nil {
		return false, err
	}
	return count > 0, nil
}
