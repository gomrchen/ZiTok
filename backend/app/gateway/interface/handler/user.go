package handler

import (
	"context"
	"strconv"

	"github.com/cloudwego/hertz/pkg/app"

	"github.com/mutezebra/tiktok/app/gateway/domain/model"
	"github.com/mutezebra/tiktok/app/gateway/interface/pack"
	"github.com/mutezebra/tiktok/app/gateway/interface/rpc"
	"github.com/mutezebra/tiktok/pkg/constants"
	"github.com/mutezebra/tiktok/pkg/kitex_gen/api/user"
)

func UserRegisterHandler() app.HandlerFunc {
	return func(ctx context.Context, c *app.RequestContext) {
		var req user.RegisterReq
		if err := c.BindAndValidate(&req); err != nil {
			pack.SendFailedResponse(c, pack.ReturnError(model.InvalidParamErrno, err))
			return
		}

		resp, err := rpc.Register(ctx, &req)
		if err != nil {
			pack.SendFailedResponse(c, err)
			return
		}

		pack.SendResponse(c, resp)
	}
}

func UserLoginHandler() app.HandlerFunc {
	return func(ctx context.Context, c *app.RequestContext) {
		var req user.LoginReq
		if err := c.BindAndValidate(&req); err != nil {
			pack.SendFailedResponse(c, pack.ReturnError(model.InvalidParamErrno, err))
			return
		}

		resp, err := rpc.Login(ctx, &req)
		if err != nil {
			pack.SendFailedResponse(c, err)
			return
		}

		pack.SendResponse(c, resp)
	}
}

func UserInfoHandler() app.HandlerFunc {
	return func(ctx context.Context, c *app.RequestContext) {
		var req user.InfoReq
		if err := c.BindAndValidate(&req); err != nil {
			pack.SendFailedResponse(c, pack.ReturnError(model.InvalidParamErrno, err))
			return
		}
		if req.UID == nil {
			req.UID = new(int64)
			*req.UID, _ = strconv.ParseInt(string(c.GetHeader(constants.HeaderUserIdKey)), 10, 64)
		}

		resp, err := rpc.Info(ctx, &req)
		if err != nil {
			pack.SendFailedResponse(c, err)
			return
		}

		pack.SendResponse(c, resp)
	}
}

func UploadAvatarHandler() app.HandlerFunc {
	return func(ctx context.Context, c *app.RequestContext) {
		fileHeader, err := c.FormFile(constants.FormUserAvatarKey)
		if err != nil {
			pack.SendFailedResponse(c, pack.ReturnError(model.InternalServerErrorErrno, err))
			return
		}

		if fileHeader.Size > constants.MB*5 {
			pack.SendFailedResponse(c, pack.ReturnError(model.OutOfLimitAvatarSizeErrno, nil))
			return
		}

		avatar, err := fileHeader.Open()
		if err != nil {
			pack.SendFailedResponse(c, pack.ReturnError(model.InternalServerErrorErrno, err))
			return
		}

		var req user.UploadAvatarReq
		req.Avatar = make([]byte, fileHeader.Size)
		_, err = avatar.Read(req.Avatar)
		if err != nil {
			pack.SendFailedResponse(c, pack.ReturnError(model.InternalServerErrorErrno, err))
			return
		}

		req.UID = new(int64)
		*req.UID, _ = strconv.ParseInt(string(c.GetHeader(constants.HeaderUserIdKey)), 10, 64)
		req.SetFileName(&fileHeader.Filename)

		resp, err := rpc.UploadAvatar(ctx, &req)
		if err != nil {
			pack.SendFailedResponse(c, err)
			return
		}

		pack.SendResponse(c, resp)
	}
}

func DownloadAvatarHandler() app.HandlerFunc {
	return func(ctx context.Context, c *app.RequestContext) {
		var req user.DownloadAvatarReq

		req.UID = new(int64)
		*req.UID, _ = strconv.ParseInt(string(c.GetHeader(constants.HeaderUserIdKey)), 10, 64)

		resp, err := rpc.DownloadAvatar(ctx, &req)
		if err != nil {
			pack.SendFailedResponse(c, err)
			return
		}

		pack.SendResponse(c, resp)
	}
}

func TotpQRCodeHandler() app.HandlerFunc {
	return func(ctx context.Context, c *app.RequestContext) {
		var req user.TotpQrcodeReq

		req.UID = new(int64)
		*req.UID, _ = strconv.ParseInt(string(c.GetHeader(constants.HeaderUserIdKey)), 10, 64)
		req.UserName = new(string)
		*req.UserName = string(c.GetHeader(constants.HeaderUserNameKey))

		resp, err := rpc.TotpQrcode(ctx, &req)
		if err != nil {
			pack.SendFailedResponse(c, err)
			return
		}

		pack.SendResponse(c, resp)
	}
}

func EnableTotpHandler() app.HandlerFunc {
	return func(ctx context.Context, c *app.RequestContext) {
		var req user.EnableTotpReq
		if err := c.BindAndValidate(&req); err != nil {
			pack.SendFailedResponse(c, pack.ReturnError(model.InvalidParamErrno, err))
			return
		}

		req.UID = new(int64)
		*req.UID, _ = strconv.ParseInt(string(c.GetHeader(constants.HeaderUserIdKey)), 10, 64)

		resp, err := rpc.EnableTotp(ctx, &req)
		if err != nil {
			pack.SendFailedResponse(c, err)
			return
		}

		pack.SendResponse(c, resp)
	}
}
