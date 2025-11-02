package usecase

import (
	"context"
	"strconv"
	"time"

	"github.com/mutezebra/tiktok/app/user/domain/model"
	"github.com/mutezebra/tiktok/app/user/domain/repository"
	userService "github.com/mutezebra/tiktok/app/user/domain/service"
	"github.com/mutezebra/tiktok/app/user/usecase/pack"
	idl "github.com/mutezebra/tiktok/pkg/kitex_gen/api/user"
	"github.com/mutezebra/tiktok/pkg/trace"
	"github.com/mutezebra/tiktok/pkg/utils"
)

type UserCase struct {
	repo    repository.UserRepository
	service *userService.Service
}

func NewUserUseCase(repo repository.UserRepository, srv *userService.Service) *UserCase {
	return &UserCase{
		repo:    repo,
		service: srv,
	}
}

type userDTO struct {
	id             int64
	username       string
	passwordDigest string
	email          string
}

func (u *UserCase) Register(ctx context.Context, req *idl.RegisterReq) (r *idl.RegisterResp, err error) {
	dto := userDTO{}
	dto.username = req.GetUserName()
	dto.id = u.service.GenerateID()

	if dto.email, err = u.service.VerifyEmail(req.GetEmail()); err != nil {
		return nil, pack.ReturnError(model.EmailFormatError, err)
	}

	if dto.passwordDigest, err = u.service.EncryptPassword(req.GetPassword()); err != nil {
		return nil, pack.ReturnError(model.EncryptPasswordError, err)
	}

	var exist bool
	if exist, err = u.repo.UserNameExists(ctx, dto.username); err != nil || exist {
		return nil, pack.ReturnError(model.DatabaseUserNameExistsError, err)
	}

	if err = u.repo.CreateUser(ctx, dtoU2Repo(&dto)); err != nil {
		return nil, pack.ReturnError(model.DatabaseCreateUserError, err)
	}

	return nil, nil
}

func (u *UserCase) Login(ctx context.Context, req *idl.LoginReq) (r *idl.LoginResp, err error) {
	passwordDigest, id, err := u.repo.GetPasswordAndIDByName(ctx, req.GetUserName())
	if err != nil {
		return nil, pack.ReturnError(model.GetPasswordFromDatabaseError, err)
	}

	ok := u.service.CheckPassword(req.GetPassword(), passwordDigest)
	if !ok {
		return nil, pack.ReturnError(model.CheckPasswordError, nil)
	}

	aToken, rToken, err := utils.GenerateToken(req.GetUserName(), id)
	if err != nil {
		return nil, pack.ReturnError(model.GenerateTokenError, err)
	}

	r = new(idl.LoginResp)
	r.SetAccessToken(&aToken)
	r.SetRefreshToken(&rToken)

	return r, nil
}

func (u *UserCase) Info(ctx context.Context, req *idl.InfoReq) (r *idl.InfoResp, err error) {
	tag := trace.NewTags()
	tag.SetSpanType("user-usecase")

	user, err := u.repo.UserInfoByID(ctx, *req.UID)
	if err != nil {
		return nil, pack.ReturnError(model.GetUserInfoError, err)
	}
	r = new(idl.InfoResp)
	r.Data = repoU2IDL(*user)

	videoList, err := u.service.GetVideoList(ctx, req.GetUID())
	if err != nil {
		return nil, pack.ReturnError(model.GetVideoListError, err)
	}
	r.VideoList = videoList

	friends, err := u.service.GetFriendsList(ctx, req.GetUID())
	if err != nil {
		return nil, pack.ReturnError(model.GetFriendListError, err)
	}
	r.Friends = friends

	fans, err := u.service.GetFansList(ctx, req.GetUID())
	if err != nil {
		return nil, pack.ReturnError(model.GetFansListError, err)
	}
	r.Fans = fans

	follows, err := u.service.GetFollowList(ctx, req.GetUID())
	if err != nil {
		return nil, pack.ReturnError(model.GetFollowListError, err)
	}
	r.Follows = follows

	likeList, err := u.service.LikeList(ctx, req.GetUID())
	if err != nil {
		return nil, pack.ReturnError(model.GetLikeListError, err)
	}
	r.LikeList = likeList

	return r, nil
}

func (u *UserCase) UploadAvatar(ctx context.Context, req *idl.UploadAvatarReq) (r *idl.UploadAvatarResp, err error) {
	ok, avatar := u.service.AvatarName(*req.FileName, *req.UID)
	if !ok {
		return nil, pack.ReturnError(model.GetAvatarNameError, nil)
	}

	err, path := u.service.UploadAvatar(ctx, avatar, req.Avatar)
	if err != nil {
		return nil, pack.ReturnError(model.OssUploadAvatarError, err)
	}

	url := u.service.DownloadAvatar(ctx, path)
	if url == "" {
		return nil, pack.ReturnError(model.OssDownloadAvatarError, err)
	}

	if err = u.repo.UpdateUserAvatar(ctx, path, *req.UID); err != nil {
		return nil, pack.ReturnError(model.DatabaseUpdateUserAvatarError, err)
	}

	r = new(idl.UploadAvatarResp)
	return r, nil
}

func (u *UserCase) DownloadAvatar(ctx context.Context, req *idl.DownloadAvatarReq) (r *idl.DownloadAvatarResp, err error) {
	path, err := u.repo.GetUserAvatar(ctx, req.GetUID())
	if err != nil {
		return nil, pack.ReturnError(model.DatabaseGetUserAvatarError, err)
	}

	url := u.service.DownloadAvatar(ctx, path)
	if url == "" {
		return nil, pack.ReturnError(model.OssDownloadAvatarError, nil)
	}

	r = new(idl.DownloadAvatarResp)
	r.SetURL(&url)
	return r, nil
}

func (u *UserCase) TotpQrcode(ctx context.Context, req *idl.TotpQrcodeReq) (r *idl.TotpQrcodeResp, err error) {
	secret, png, err := u.service.GenerateTotp(req.GetUserName())
	if err != nil {
		return nil, pack.ReturnError(model.GenerateTotpError, err)
	}

	err = u.repo.UpdateTotpSecret(ctx, req.GetUID(), secret)
	if err != nil {
		return nil, pack.ReturnError(model.DatabaseUpdateTotpSecretError, err)
	}

	r = new(idl.TotpQrcodeResp)
	r.SetQrcode(&png)
	return r, nil
}

func (u *UserCase) EnableTotp(ctx context.Context, req *idl.EnableTotpReq) (r *idl.EnableTotpResp, err error) {
	secret, err := u.repo.GetTotpSecret(ctx, req.GetUID())
	if err != nil {
		return nil, pack.ReturnError(model.DatabaseGetTotpSecretError, err)
	}

	ok := u.service.VerifyOtp(req.GetCode(), secret)
	if !ok {
		return nil, pack.ReturnError(model.VerifyOtpCodeError, err)
	}

	err = u.repo.UpdateTotpStatus(ctx, true, req.GetUID())
	if err != nil {
		return nil, pack.ReturnError(model.DatabaseUpdateTotpStatusError, err)
	}

	r = new(idl.EnableTotpResp)
	return r, nil
}

// toUser is userDTO to repository.user
func dtoU2Repo(dto *userDTO) *repository.User {
	return &repository.User{
		ID:             dto.id,
		UserName:       dto.username,
		Email:          dto.email,
		PasswordDigest: dto.passwordDigest,
		Gender:         -1,
		Avatar:         "",
		Fans:           0,
		Follows:        0,
		TotpEnable:     false,
		TotpSecret:     "",
		CreateAt:       time.Now().Unix(),
		UpdateAt:       time.Now().Unix(),
		DeleteAt:       0,
	}
}

func repoU2IDL(user repository.User) *idl.UserInfo {
	uid := strconv.FormatInt(user.ID, 10)
	return &idl.UserInfo{
		ID:         &uid,
		UserName:   &user.UserName,
		Email:      &user.Email,
		Gender:     &user.Gender,
		Avatar:     &user.Avatar,
		Fans:       &user.Fans,
		Follows:    &user.Follows,
		CreateAt:   &user.CreateAt,
		UpdateAt:   &user.UpdateAt,
		TotpStatus: &user.TotpEnable,
	}
}
