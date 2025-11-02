package model

import "github.com/mutezebra/tiktok/pkg/errno"

var (
	SuccessErrno              = errno.New(Success, "operate success")
	InvalidParamErrno         = errno.New(InvalidParams, "invalid param")
	UnauthorizedErrno         = errno.New(Unauthorized, "unauthorized")
	InternalServerErrorErrno  = errno.New(InternalServerError, "internal server failed")
	OutOfLimitAvatarSizeErrno = errno.New(OutOfLimitAvatarSize, "out of limit avatar size")
	OutOfLimitCoverSizeErrno  = errno.New(OutOfLimitCoverSize, "out of limit cover size")
)

// ChatRegisterError chat
var (
	ChatRegisterError = errno.New(ChatRegister, "chat register failed")
)
