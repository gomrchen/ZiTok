package rpc

import (
	"context"

	"github.com/bytedance/gopkg/cloud/metainfo"

	"github.com/mutezebra/tiktok/pkg/constants"
	"github.com/mutezebra/tiktok/pkg/kitex_gen/api/user"
)

func Register(ctx context.Context, req *user.RegisterReq) (r *user.RegisterResp, err error) {
	ctx = metainfo.WithPersistentValue(ctx, constants.TracingRpcMethod, "userService.Register")
	if err = handlerUserClient(); err != nil {
		return nil, err
	}
	r, err = UserClient.Register(ctx, req)
	return r, err
}

func Login(ctx context.Context, req *user.LoginReq) (r *user.LoginResp, err error) {
	if err = handlerUserClient(); err != nil {
		return nil, err
	}
	return UserClient.Login(ctx, req)
}

func Info(ctx context.Context, req *user.InfoReq) (r *user.InfoResp, err error) {
	ctx = metainfo.WithPersistentValue(ctx, constants.TracingRpcMethod, "userService.Info")
	if err = handlerUserClient(); err != nil {
		return nil, err
	}
	r, err = UserClient.Info(ctx, req)
	return r, err
}

func UploadAvatar(ctx context.Context, req *user.UploadAvatarReq) (r *user.UploadAvatarResp, err error) {
	if err = handlerUserClient(); err != nil {
		return nil, err
	}
	return UserClient.UploadAvatar(ctx, req)
}

func DownloadAvatar(ctx context.Context, req *user.DownloadAvatarReq) (r *user.DownloadAvatarResp, err error) {
	if err = handlerUserClient(); err != nil {
		return nil, err
	}
	return UserClient.DownloadAvatar(ctx, req)
}

func TotpQrcode(ctx context.Context, req *user.TotpQrcodeReq) (r *user.TotpQrcodeResp, err error) {
	if err = handlerUserClient(); err != nil {
		return nil, err
	}
	return UserClient.TotpQrcode(ctx, req)
}

func EnableTotp(ctx context.Context, req *user.EnableTotpReq) (r *user.EnableTotpResp, err error) {
	if err = handlerUserClient(); err != nil {
		return nil, err
	}
	return UserClient.EnableTotp(ctx, req)
}

func handlerUserClient() error {
	return lostConnect(UserClient, "user")
}
