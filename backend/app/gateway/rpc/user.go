package rpc

import (
	"bytes"
	"context"
	"encoding/json"
	"log"
	"net/http"

	"github.com/yxrxy/videoHub/kitex_gen/model"
	"github.com/yxrxy/videoHub/kitex_gen/user"
	"github.com/yxrxy/videoHub/pkg/base/client"
	"github.com/yxrxy/videoHub/pkg/errno"
)

// InitUserRPC 初始化用户服务客户端
func InitUserRPC() {
	c, err := client.InitUserRPC()
	if err != nil {
		log.Fatalf("初始化用户服务客户端失败: %v", err)
	}
	userClient = *c
}

// UpdateUserInfoRPC 更新用户信息 (新增)
func UpdateUserInfoRPC(ctx context.Context, req *user.UpdateUserInfoRequest) (*user.UpdateUserInfoResponse, error) {
	resp, err := userClient.UpdateUserInfo(ctx, req)
	if err != nil {
		log.Printf("更新用户信息RPC调用失败: %v", err)
		return nil, errno.InternalServiceError.WithError(err)
	}
	if resp.Base.Code != errno.SuccessCode {
		return nil, errno.InternalServiceError.WithMessage(resp.Base.Msg)
	}
	return resp, nil
}

// RegisterRPC 用户注册
func RegisterRPC(ctx context.Context, req *user.RegisterRequest) (int64, error) {
	resp, err := userClient.Register(ctx, req)
	if err != nil {
		log.Printf("注册用户RPC调用失败: %v", err)
		return 0, errno.InternalServiceError.WithError(err)
	}
	if resp.Base.Code != errno.SuccessCode {
		return 0, errno.InternalServiceError.WithMessage(resp.Base.Msg)
	}
	return resp.UserId, nil
}

// LoginRPC 用户登录
func LoginRPC(ctx context.Context, req *user.LoginRequest) (*user.LoginResponse, error) {
	resp, err := userClient.Login(ctx, req)
	if err != nil {
		log.Printf("用户登录RPC调用失败: %v", err)
		return nil, errno.InternalServiceError.WithError(err)
	}
	if resp.Base.Code != errno.SuccessCode {
		return nil, errno.InternalServiceError.WithMessage(resp.Base.Msg)
	}
	return resp, nil
}

// GetUserInfoRPC 获取用户信息
func GetUserInfoRPC(ctx context.Context, req *user.UserInfoRequest) (*model.User, error) {
	resp, err := userClient.GetUserInfo(ctx, req)
	if err != nil {
		log.Printf("获取用户信息RPC调用失败: %v", err)
		return nil, errno.InternalServiceError.WithError(err)
	}
	if resp.Base.Code != errno.SuccessCode {
		return nil, errno.InternalServiceError.WithMessage(resp.Base.Msg)
	}
	return resp.User, nil
}

// UploadAvatarRPC 上传头像
func UploadAvatarRPC(ctx context.Context, req *user.UploadAvatarRequest) (*model.User, error) {
	resp, err := userClient.UploadAvatar(ctx, req)
	if err != nil {
		log.Printf("上传头像RPC调用失败: %v", err)
		return nil, errno.InternalServiceError.WithError(err)
	}
	if resp.Base.Code != errno.SuccessCode {
		return nil, errno.InternalServiceError.WithMessage(resp.Base.Msg)
	}
	return resp.User, nil
}

// UploadBackgroundRPC 上传背景图片 (新增)
func UploadBackgroundRPC(ctx context.Context, req *user.UploadBackgroundRequest) (*model.User, error) {
	resp, err := userClient.UploadBackground(ctx, req)
	if err != nil {
		log.Printf("上传背景图片RPC调用失败: %v", err)
		return nil, errno.InternalServiceError.WithError(err)
	}
	if resp.Base.Code != errno.SuccessCode {
		return nil, errno.InternalServiceError.WithMessage(resp.Base.Msg)
	}
	return resp.User, nil
}

// RefreshTokenRPC 刷新令牌
func RefreshTokenRPC(ctx context.Context, req *user.RefreshTokenRequest) (*user.RefreshTokenResponse, error) {
	resp, err := userClient.RefreshToken(ctx, req)
	if err != nil {
		log.Printf("刷新令牌RPC调用失败: %v", err)
		return nil, errno.InternalServiceError.WithError(err)
	}
	if resp.Base.Code != errno.SuccessCode {
		return nil, errno.InternalServiceError.WithMessage(resp.Base.Msg)
	}
	return resp, nil
}

// VerifyEmailCodeRequest 验证邮箱验证码请求结构
type VerifyEmailCodeRequest struct {
	Email string `json:"email"`
	Code  string `json:"code"`
}

// VerifyEmailCodeResponse 验证邮箱验证码响应结构
type VerifyEmailCodeResponse struct {
	Success bool        `json:"success"`
	Message string      `json:"message"`
	Data    interface{} `json:"data"`
}

// VerifyEmailCode 验证邮箱验证码
func VerifyEmailCode(ctx context.Context, email, code string) error {
	// 构造请求数据
	requestData := VerifyEmailCodeRequest{
		Email: email,
		Code:  code,
	}

	// 序列化请求数据
	jsonData, err := json.Marshal(requestData)
	if err != nil {
		return errno.InternalServiceError.WithError(err)
	}

	// 发送HTTP请求
	resp, err := http.Post("http://106.53.190.84:8000/api/v1/verify_code", "application/json", bytes.NewBuffer(jsonData))
	if err != nil {
		return errno.InternalServiceError.WithError(err)
	}
	defer resp.Body.Close()

	// 解析响应数据
	var verifyResp VerifyEmailCodeResponse
	if err := json.NewDecoder(resp.Body).Decode(&verifyResp); err != nil {
		return errno.InternalServiceError.WithError(err)
	}

	// 检查验证结果
	if !verifyResp.Success {
		return errno.NewErrNo(errno.ParamVerifyErrorCode, verifyResp.Message)
	}

	return nil
}

// FindUserByEmailRPC 根据邮箱查找用户ID
func FindUserByEmailRPC(ctx context.Context, req *user.FindUserByEmailRequest) (*user.FindUserByEmailResponse, error) {
	resp, err := userClient.FindUserByEmail(ctx, req)
	if err != nil {
		log.Printf("根据邮箱查找用户ID RPC调用失败: %v", err)
		return nil, errno.InternalServiceError.WithError(err)
	}
	if resp.Base.Code != errno.SuccessCode {
		return nil, errno.InternalServiceError.WithMessage(resp.Base.Msg)
	}
	return resp, nil
}

// FindUsersByUsernameRPC 根据用户名模糊匹配查找用户
func FindUsersByUsernameRPC(ctx context.Context, req *user.FindUsersByUsernameRequest) (*user.FindUsersByUsernameResponse, error) {
	resp, err := userClient.FindUsersByUsername(ctx, req)
	if err != nil {
		log.Printf("根据用户名模糊匹配查找用户 RPC调用失败: %v", err)
		return nil, errno.InternalServiceError.WithError(err)
	}
	if resp.Base.Code != errno.SuccessCode {
		return nil, errno.InternalServiceError.WithMessage(resp.Base.Msg)
	}
	return resp, nil
}

// --- 收藏相关RPC方法 ---

// FavoriteVideoRPC 收藏视频
func FavoriteVideoRPC(ctx context.Context, req *user.FavoriteVideoRequest) (*user.FavoriteVideoResponse, error) {
	resp, err := userClient.FavoriteVideo(ctx, req)
	if err != nil {
		log.Printf("收藏视频RPC调用失败: %v", err)
		return nil, errno.InternalServiceError.WithError(err)
	}
	if resp.Base.Code != errno.SuccessCode {
		return nil, errno.InternalServiceError.WithMessage(resp.Base.Msg)
	}
	return resp, nil
}

// UnfavoriteVideoRPC 取消收藏视频
func UnfavoriteVideoRPC(ctx context.Context, req *user.UnfavoriteVideoRequest) (*user.UnfavoriteVideoResponse, error) {
	resp, err := userClient.UnfavoriteVideo(ctx, req)
	if err != nil {
		log.Printf("取消收藏视频RPC调用失败: %v", err)
		return nil, errno.InternalServiceError.WithError(err)
	}
	if resp.Base.Code != errno.SuccessCode {
		return nil, errno.InternalServiceError.WithMessage(resp.Base.Msg)
	}
	return resp, nil
}

// GetFavoriteVideosRPC 获取用户收藏的视频列表
func GetFavoriteVideosRPC(ctx context.Context, req *user.GetFavoriteVideosRequest) (*user.GetFavoriteVideosResponse, error) {
	resp, err := userClient.GetFavoriteVideos(ctx, req)
	if err != nil {
		log.Printf("获取用户收藏的视频列表RPC调用失败: %v", err)
		return nil, errno.InternalServiceError.WithError(err)
	}
	if resp.Base.Code != errno.SuccessCode {
		return nil, errno.InternalServiceError.WithMessage(resp.Base.Msg)
	}
	return resp, nil
}