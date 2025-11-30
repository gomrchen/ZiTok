package rpc

import (
	"context"

	"github.com/yxrxy/videoHub/app/user/controllers/rpc/pack"
	"github.com/yxrxy/videoHub/app/user/domain/model"
	"github.com/yxrxy/videoHub/app/user/usecase"
	model2 "github.com/yxrxy/videoHub/kitex_gen/model"
	"github.com/yxrxy/videoHub/kitex_gen/user"
	"github.com/yxrxy/videoHub/pkg/base"
	uc "github.com/yxrxy/videoHub/pkg/base/context"
)

type UserHandler struct {
	useCase usecase.UserUseCase
}

func NewUserHandler(useCase usecase.UserUseCase) *UserHandler {
	return &UserHandler{useCase: useCase}
}

func (h *UserHandler) Register(ctx context.Context, req *user.RegisterRequest) (r *user.RegisterResponse, err error) {
	r = new(user.RegisterResponse)
	u := &model.User{
		Username: req.Username,
		Password: req.Password,
	}
	if req.Email == nil {
		u.Email = req.Username
	}

	var uid int64
	if uid, err = h.useCase.Register(ctx, u); err != nil {
		return
	}
	r.Base = base.BuildBaseResp(err)
	r.UserId = uid
	return
}

func (h *UserHandler) Login(ctx context.Context, req *user.LoginRequest) (r *user.LoginResponse, err error) {
	r = new(user.LoginResponse)
	u := &model.User{
		Username: req.Username,
		Password: req.Password,
	}

	var user *model.User
	if user, err = h.useCase.Login(ctx, u); err != nil {
		return
	}
	r.UserId = user.ID
	r.Token = user.Token
	r.RefreshToken = user.RefreshToken
	r.Base = base.BuildBaseResp(err)
	return
}

func (h *UserHandler) GetUserInfo(ctx context.Context, req *user.UserInfoRequest) (r *user.UserInfoResponse, err error) {
	r = new(user.UserInfoResponse)

	var user *model.User
	if user, err = h.useCase.GetUserInfo(ctx, req.UserId); err != nil {
		return
	}
	r.User = pack.User(user)
	r.Base = base.BuildBaseResp(err)
	return
}

func (h *UserHandler) UploadAvatar(ctx context.Context, req *user.UploadAvatarRequest) (r *user.UploadAvatarResponse, err error) {
	r = new(user.UploadAvatarResponse)
	uid, err := uc.GetUserID(ctx)
	if err != nil {
		return
	}

	var user *model.User
	if user, err = h.useCase.UploadAvatar(ctx, uid, req.AvatarData, req.ContentType); err != nil {
		return
	}
	r.User = pack.User(user)
	r.Base = base.BuildBaseResp(err)
	return
}

func (h *UserHandler) UploadBackground(ctx context.Context, req *user.UploadBackgroundRequest) (r *user.UploadBackgroundResponse, err error) {
	r = new(user.UploadBackgroundResponse)
	uid, err := uc.GetUserID(ctx)
	if err != nil {
		return
	}

	var user *model.User
	if user, err = h.useCase.UploadBackground(ctx, uid, req.BackgroundData, req.ContentType); err != nil {
		return
	}
	r.User = pack.User(user)
	r.Base = base.BuildBaseResp(err)
	return
}

func (h *UserHandler) UpdateUserInfo(ctx context.Context, req *user.UpdateUserInfoRequest) (r *user.UpdateUserInfoResponse, err error) {
	r = new(user.UpdateUserInfoResponse)
	uid, err := uc.GetUserID(ctx)
	if err != nil {
		return
	}
	if req.UserId != nil {
		uid = *req.UserId
	}

	// Create user model with update data
	u := &model.User{
		ID: uid,
	}

	if req.Username != nil {
		u.Username = *req.Username
	}

	if req.Password != nil {
		u.Password = *req.Password
	}

	if req.Gender != nil {
		u.Gender = *req.Gender
	}

	if req.Birthday != nil {
		u.Birthday = *req.Birthday
	}

	if req.Email != nil {
		u.Email = *req.Email
	}

	if req.Signature != nil {
		u.Signature = *req.Signature
	}

	// Call usecase to update user info
	if err = h.useCase.UpdateUserInfo(ctx, uid, u); err != nil {
		return
	}

	r.Base = base.BuildBaseResp(err)
	return
}

func (h *UserHandler) RefreshToken(ctx context.Context, req *user.RefreshTokenRequest) (r *user.RefreshTokenResponse, err error) {
	r = new(user.RefreshTokenResponse)

	var token, refreshToken string
	if token, refreshToken, err = h.useCase.RefreshToken(ctx, req.UserId, req.RefreshToken); err != nil {
		return
	}
	r.Token = token
	r.RefreshToken = refreshToken
	r.Base = base.BuildBaseResp(err)
	return
}

// FindUserByEmail 根据邮箱查找用户ID
func (h *UserHandler) FindUserByEmail(ctx context.Context, req *user.FindUserByEmailRequest) (r *user.FindUserByEmailResponse, err error) {
	r = new(user.FindUserByEmailResponse)

	var userID int64
	if userID, err = h.useCase.FindUserByEmail(ctx, req.Email); err != nil {
		r.Base = base.BuildBaseResp(err)
		return
	}

	r.UserId = userID
	r.Base = base.BuildBaseResp(nil)
	return
}

// FindUsersByUsername 根据用户名模糊匹配查找用户
func (h *UserHandler) FindUsersByUsername(ctx context.Context, req *user.FindUsersByUsernameRequest) (r *user.FindUsersByUsernameResponse, err error) {
	r = new(user.FindUsersByUsernameResponse)

	var users []*model.User
	if users, err = h.useCase.FindUsersByUsername(ctx, req.Username); err != nil {
		r.Base = base.BuildBaseResp(err)
		return
	}

	// 转换用户数据
	userBriefs := make([]*user.UserBrief, len(users))
	for i, u := range users {
		userBriefs[i] = &user.UserBrief{
			UserId:    u.ID,
			Username:  u.Username,
			AvatarUrl: u.AvatarURL,
		}
	}

	r.Users = userBriefs
	r.Base = base.BuildBaseResp(nil)
	return
}

// --- 收藏相关方法 ---

// FavoriteVideo 收藏视频
func (h *UserHandler) FavoriteVideo(ctx context.Context, req *user.FavoriteVideoRequest) (r *user.FavoriteVideoResponse, err error) {
	r = new(user.FavoriteVideoResponse)

	// 获取用户ID
	uid, err := uc.GetUserID(ctx)
	if err != nil {
		r.Base = base.BuildBaseResp(err)
		return
	}

	// 调用usecase进行收藏操作
	if err = h.useCase.FavoriteVideo(ctx, uid, req.VideoId); err != nil {
		r.Base = base.BuildBaseResp(err)
		return
	}

	r.Base = base.BuildBaseResp(nil)
	return
}

// UnfavoriteVideo 取消收藏视频
func (h *UserHandler) UnfavoriteVideo(ctx context.Context, req *user.UnfavoriteVideoRequest) (r *user.UnfavoriteVideoResponse, err error) {
	r = new(user.UnfavoriteVideoResponse)

	// 获取用户ID
	uid, err := uc.GetUserID(ctx)
	if err != nil {
		r.Base = base.BuildBaseResp(err)
		return
	}

	// 调用usecase进行取消收藏操作
	if err = h.useCase.UnfavoriteVideo(ctx, uid, req.VideoId); err != nil {
		r.Base = base.BuildBaseResp(err)
		return
	}

	r.Base = base.BuildBaseResp(nil)
	return
}

// GetFavoriteVideos 获取用户收藏的视频列表
func (h *UserHandler) GetFavoriteVideos(ctx context.Context, req *user.GetFavoriteVideosRequest) (r *user.GetFavoriteVideosResponse, err error) {
	r = new(user.GetFavoriteVideosResponse)

	// 获取用户ID
	uid, err := uc.GetUserID(ctx)
	if err != nil {
		r.Base = base.BuildBaseResp(err)
		return
	}

	// 调用usecase获取收藏视频列表
	videoIDs, total, err := h.useCase.GetFavoriteVideos(ctx, uid, int(req.Page), int(req.Size))
	if err != nil {
		r.Base = base.BuildBaseResp(err)
		return
	}

	// 构造响应
	r.VideoList = make([]*model2.Video, len(videoIDs))
	for i, videoID := range videoIDs {
		r.VideoList[i] = &model2.Video{
			Id: videoID,
		}
	}
	r.Total = total
	r.Base = base.BuildBaseResp(nil)
	return
}
