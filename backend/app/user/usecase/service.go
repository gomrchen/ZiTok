package usecase

import (
	"context"

	"github.com/yxrxy/videoHub/app/user/domain/model"
	"github.com/yxrxy/videoHub/pkg/errno"
)

func (s *useCase) Register(ctx context.Context, req *model.User) (int64, error) {
	exist, err := s.db.IsUserExist(ctx, req.Username)
	if err != nil {
		return 0, errno.NewErrNo(errno.InternalDatabaseErrorCode, "database error")
	}
	if exist {
		return 0, errno.NewErrNo(errno.ServiceUserExist, "user already exist")
	}

	return s.svc.Register(ctx, req)
}

func (s *useCase) Login(ctx context.Context, req *model.User) (*model.User, error) {
	exist, err := s.db.IsUserExist(ctx, req.Username)
	if err != nil {
		return nil, errno.NewErrNo(errno.InternalDatabaseErrorCode, "database error")
	}
	if !exist {
		return nil, errno.NewErrNo(errno.ServiceUserNotExist, "user not exist")
	}

	return s.svc.Login(ctx, req)
}

func (s *useCase) GetUserInfo(ctx context.Context, uid int64) (*model.User, error) {
	return s.db.GetUserByID(ctx, uid)
}

// UpdateUserInfo 更新用户信息 (新增)
func (s *useCase) UpdateUserInfo(ctx context.Context, uid int64, req *model.User) error {
	// 1. 检查用户是否存在
	exist, err := s.db.IsUserExistByID(ctx, uid)
	if err != nil {
		return errno.NewErrNo(errno.InternalDatabaseErrorCode, "database error")
	}
	if !exist {
		return errno.NewErrNo(errno.ServiceUserNotExist, "user not exist")
	}

	// 2. 调用服务层或DB层进行更新
	// 这里假设 s.svc.UpdateUserInfo 或 s.db.UpdateUser 负责实际的更新逻辑
	// 传入的 req 包含需要更新的字段 (Signature, Gender, Birthday, Email 等)
	req.ID = uid // 确保 ID 正确
	return s.db.UpdateUser(ctx, req)
}

func (s *useCase) UploadAvatar(ctx context.Context, uid int64, avatarData []byte, contentType string) (*model.User, error) {
	exist, err := s.db.IsUserExistByID(ctx, uid)
	if err != nil {
		return nil, errno.NewErrNo(errno.InternalDatabaseErrorCode, "database error")
	}
	if !exist {
		return nil, errno.NewErrNo(errno.ServiceUserNotExist, "user not exist")
	}

	return s.svc.UploadAvatar(ctx, uid, avatarData, contentType)
}

// UploadBackground 上传背景图片 (新增)
func (s *useCase) UploadBackground(ctx context.Context, uid int64, backgroundData []byte, contentType string) (*model.User, error) {
	// 1. 检查用户是否存在
	exist, err := s.db.IsUserExistByID(ctx, uid)
	if err != nil {
		return nil, errno.NewErrNo(errno.InternalDatabaseErrorCode, "database error")
	}
	if !exist {
		return nil, errno.NewErrNo(errno.ServiceUserNotExist, "user not exist")
	}

	// 2. 调用服务层处理上传和更新逻辑
	// 类似于 UploadAvatar，这里调用 service 层的 UploadBackground 方法
	return s.svc.UploadBackground(ctx, uid, backgroundData, contentType)
}

func (s *useCase) RefreshToken(ctx context.Context, uid int64, refreshToken string) (string, string, error) {
	// Get user to verify existence
	_, err := s.db.GetUserByID(ctx, uid)
	if err != nil {
		return "", "", errno.NewErrNo(errno.ServiceUserNotExist, "user not exist")
	}

	// Call service layer to refresh token
	return s.svc.RefreshToken(ctx, refreshToken)
}

// FindUserByEmail 根据邮箱查找用户ID
func (s *useCase) FindUserByEmail(ctx context.Context, email string) (int64, error) {
	return s.db.FindUserByEmail(ctx, email)
}

// FindUsersByUsername 根据用户名模糊匹配查找用户
func (s *useCase) FindUsersByUsername(ctx context.Context, username string) ([]*model.User, error) {
	return s.db.FindUsersByUsername(ctx, username)
}

// --- 收藏相关方法 ---

// FavoriteVideo 收藏视频
func (s *useCase) FavoriteVideo(ctx context.Context, uid int64, videoID int64) error {
	// 检查用户是否存在
	exist, err := s.db.IsUserExistByID(ctx, uid)
	if err != nil {
		return errno.NewErrNo(errno.InternalDatabaseErrorCode, "database error")
	}
	if !exist {
		return errno.NewErrNo(errno.ServiceUserNotExist, "user not exist")
	}

	// 调用数据库层进行收藏操作
	return s.db.FavoriteVideo(ctx, uid, videoID)
}

// UnfavoriteVideo 取消收藏视频
func (s *useCase) UnfavoriteVideo(ctx context.Context, uid int64, videoID int64) error {
	// 检查用户是否存在
	exist, err := s.db.IsUserExistByID(ctx, uid)
	if err != nil {
		return errno.NewErrNo(errno.InternalDatabaseErrorCode, "database error")
	}
	if !exist {
		return errno.NewErrNo(errno.ServiceUserNotExist, "user not exist")
	}

	// 调用数据库层进行取消收藏操作
	return s.db.UnfavoriteVideo(ctx, uid, videoID)
}

// GetFavoriteVideos 获取用户收藏的视频列表
func (s *useCase) GetFavoriteVideos(ctx context.Context, uid int64, page, size int) ([]int64, int64, error) {
	// 检查用户是否存在
	exist, err := s.db.IsUserExistByID(ctx, uid)
	if err != nil {
		return nil, 0, errno.NewErrNo(errno.InternalDatabaseErrorCode, "database error")
	}
	if !exist {
		return nil, 0, errno.NewErrNo(errno.ServiceUserNotExist, "user not exist")
	}

	// 调用数据库层获取收藏视频列表
	return s.db.GetFavoriteVideos(ctx, uid, page, size)
}
