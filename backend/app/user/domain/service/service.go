package service

import (
	"context"
	"crypto/md5"
	"errors"
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/go-redis/redis/v8"
	"github.com/yxrxy/videoHub/app/user/domain/model"
	"github.com/yxrxy/videoHub/config"
	"github.com/yxrxy/videoHub/pkg/errno"
	"github.com/yxrxy/videoHub/pkg/jwt"
	"github.com/yxrxy/videoHub/pkg/storage"
)

// Register 注册逻辑
func (s *UserService) Register(ctx context.Context, req *model.User) (int64, error) {
	passwordHash := fmt.Sprintf("%x", md5.Sum([]byte(req.Password)))

	newUser := &model.User{
		Username:  req.Username,
		Password:  passwordHash,
		Email:     req.Email, // 处理 Email
		AvatarURL: config.User.DefaultAvatar,
        // BackgroundURL 可以设置默认值，或者为空
	}

	id, err := s.db.CreateUser(ctx, newUser)
	if err != nil {
		return 0, err
	}

	return id, nil
}

// Login 登录逻辑
func (s *UserService) Login(ctx context.Context, u *model.User) (*model.User, error) {
	// 从数据库获取用户信息
	dbUser, err := s.db.GetUserInfo(ctx, u.Username)
	if err != nil {
		return nil, err
	}

	// 计算输入密码的哈希值
	inputPasswordHash := fmt.Sprintf("%x", md5.Sum([]byte(u.Password)))

	// 比较密码哈希值
	if inputPasswordHash != dbUser.Password {
		return nil, errno.NewErrNo(errno.ServiceWrongPassword, "密码错误")
	}

	token, err := jwt.GenerateToken(dbUser.ID)
	if err != nil {
		return nil, err
	}

	refreshToken, err := jwt.GenerateRefreshToken(dbUser.ID)
	if err != nil {
		return nil, err
	}

	// 将令牌存入缓存
	if err := s.cache.SetUserAccessToken(ctx, fmt.Sprintf("access_token:%d", dbUser.ID), token); err != nil {
		log.Printf("failed to cache access token: %v", err)
	}
	if err := s.cache.SetUserRefreshToken(ctx, fmt.Sprintf("refresh_token:%d", dbUser.ID), refreshToken); err != nil {
		log.Printf("failed to cache refresh token: %v", err)
	}

    // 返回完整的用户信息，包括新生成的 token
    dbUser.Token = token
    dbUser.RefreshToken = refreshToken
    
	return dbUser, nil
}

// UploadAvatar 上传头像并更新 DB，返回更新后的 User
func (s *UserService) UploadAvatar(ctx context.Context, uid int64, avatarData []byte, contentType string) (*model.User, error) {
	if !isValidImageType(contentType) {
		return nil, errno.NewErrNo(errno.InternalServiceErrorCode, "invalid param: content type")
	}

	fileName := fmt.Sprintf("avatar_%d_%d.%s", uid, time.Now().Unix(), getFileExt(contentType))

	storage := storage.NewLocalStorage(config.Upload.Avatar.UploadDir, config.Upload.Avatar.BaseURL)
	avatarURL, err := storage.Save(avatarData, fileName)
	if err != nil {
		return nil, err
	}

    // 更新 DB
	if err := s.db.UpdateAvatar(ctx, &model.User{
		ID:        uid,
		AvatarURL: avatarURL,
	}); err != nil {
		return nil, err
	}

    // 获取最新用户信息返回
    return s.db.GetUserByID(ctx, uid)
}

// UploadBackground 上传背景图并更新 DB，返回更新后的 User (新增)
func (s *UserService) UploadBackground(ctx context.Context, uid int64, backgroundData []byte, contentType string) (*model.User, error) {
	if !isValidImageType(contentType) {
		return nil, errno.NewErrNo(errno.InternalServiceErrorCode, "invalid param: content type")
	}

	fileName := fmt.Sprintf("bg_%d_%d.%s", uid, time.Now().Unix(), getFileExt(contentType))

    // 假设使用与头像相同的存储策略，或者可以在 config 中配置独立的 Background 目录
	storage := storage.NewLocalStorage(config.Upload.Avatar.UploadDir, config.Upload.Avatar.BaseURL)
	bgURL, err := storage.Save(backgroundData, fileName)
	if err != nil {
		return nil, err
	}

    // 更新 DB (需要在 repository 中实现 UpdateBackground)
	if err := s.db.UpdateBackground(ctx, &model.User{
		ID:            uid,
		BackgroundURL: bgURL,
	}); err != nil {
		return nil, err
	}

    // 获取最新用户信息返回
    return s.db.GetUserByID(ctx, uid)
}


func isValidImageType(contentType string) bool {
	ct := strings.TrimSpace(strings.ToLower(contentType))
	// 空类型由网关按扩展名兜底；仍兼容历史客户端
	if ct == "" || ct == "application/octet-stream" {
		return true
	}
	validTypes := map[string]bool{
		"image/jpeg": true,
		"image/png":  true,
		"image/jpg":  true,
		"image/gif":  true,
		"image/webp": true,
	}
	return validTypes[ct]
}

func getFileExt(contentType string) string {
	switch contentType {
	case "image/jpeg":
		return "jpg"
	case "image/png":
		return "png"
	case "image/gif":
		return "gif"
	default:
		return "jpg"
	}
}

// RefreshToken 根据 refresh_token 刷新并返回双 token
// 修改：入参为 refreshToken 字符串，返回 (accessToken, refreshToken, error)
func (s *UserService) RefreshToken(ctx context.Context, refreshTokenStr string) (string, string, error) {
    // 1. 解析传入的 refresh token
	claims, err := jwt.ParseRefreshToken(refreshTokenStr)
	if err != nil {
		return "", "", errno.NewErrNo(errno.AuthRefreshExpiredCode, "invalid refresh token")
	}
    
    uid := claims.UserID

    // 2. 验证缓存中的 refresh token 是否一致 (可选，增强安全性)
	cachedToken, err := s.cache.GetToken(ctx, fmt.Sprintf("refresh_token:%d", uid))
	if err != nil {
		if errors.Is(err, redis.Nil) { 
			return "", "", errno.NewErrNo(errno.AuthRefreshExpiredCode, "refresh token expired")
		}
		return "", "", errno.NewErrNo(errno.InternalRedisErrorCode, "failed to get refresh token")
	}
    if cachedToken != refreshTokenStr {
        return "", "", errno.NewErrNo(errno.AuthRefreshExpiredCode, "token mismatch")
    }

    // 3. 生成新双 token
	newToken, err := jwt.GenerateToken(uid)
	if err != nil {
		return "", "", err
	}
    
    // 这里不仅生成 AccessToken，通常 RefreshToken 也建议一起轮转，或者保持原样
    // 假设我们一起轮转：
    newRefreshToken, err := jwt.GenerateRefreshToken(uid)
    if err != nil {
        return "", "", err
    }

    // 4. 更新缓存
    if err := s.cache.SetUserAccessToken(ctx, fmt.Sprintf("access_token:%d", uid), newToken); err != nil {
		log.Printf("failed to cache access token: %v", err)
	}
	if err := s.cache.SetUserRefreshToken(ctx, fmt.Sprintf("refresh_token:%d", uid), newRefreshToken); err != nil {
		log.Printf("failed to cache refresh token: %v", err)
	}

	return newToken, newRefreshToken, nil
}