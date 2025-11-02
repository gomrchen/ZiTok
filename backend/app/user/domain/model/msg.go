package model

import errno2 "github.com/mutezebra/tiktok/pkg/errno"

// User errno msgs
var (
	UserRegisterError           = errno2.New(UserRegister, "")
	EncryptPasswordError        = errno2.New(EncryptPassword, "encrypt password failed")
	DatabaseCreateUserError     = errno2.New(DatabaseCreateUser, "create user failed")
	EmailFormatError            = errno2.New(EmailFormat, "email format errno")
	DatabaseUserNameExistsError = errno2.New(DatabaseUserNameExists, "user name exists in database")

	UserLoginError               = errno2.New(UserLogin, "")
	GetPasswordFromDatabaseError = errno2.New(GetPasswordFromDatabase, "get password digest from db failed")
	CheckPasswordError           = errno2.New(CheckPassword, "checkout password failed")
	GenerateTokenError           = errno2.New(GenerateToken, "generate token failed")

	UserInfoError      = errno2.New(UserInfo, "")
	GetUserInfoError   = errno2.New(GetUserInfo, "get user info failed")
	GetFriendListError = errno2.New(GetFriendList, "get friend list failed")
	GetFansListError   = errno2.New(GetFansList, "get fans list failed")
	GetFollowListError = errno2.New(GetFollowList, "get follow list failed")
	GetVideoListError  = errno2.New(GetVideoList, "get video list failed")
	GetLikeListError   = errno2.New(GetLikeList, "get like list failed")

	UserUploadAvatarError         = errno2.New(UserUploadAvatar, "")
	GetAvatarNameError            = errno2.New(GetAvatarName, "get avatar name failed")
	OssUploadAvatarError          = errno2.New(OssUploadAvatar, "oss upload avatar failed")
	DatabaseUpdateUserAvatarError = errno2.New(DatabaseUpdateUserAvatar, "database update user avatar failed")
	OutOfLimitAvatarSizeErrno     = errno2.New(OutOfLimitAvatarSize, "the avatar size out of the limit")

	DownloadAvatarError        = errno2.New(DownloadAvatar, "")
	DatabaseGetUserAvatarError = errno2.New(DatabaseGetUserAvatar, "get user avatar from database failed")
	OssDownloadAvatarError     = errno2.New(OssDownloadAvatar, "download avatar from oss failed")

	TotpQrCodeError               = errno2.New(TotpQrCode, "")
	GenerateTotpError             = errno2.New(GenerateTotp, "generate totp qrcode failed")
	DatabaseUpdateTotpSecretError = errno2.New(DatabaseUpdateTotpSecret, "database update totp secret failed")

	EnableTotpError               = errno2.New(EnableTotp, "")
	DatabaseGetTotpSecretError    = errno2.New(DatabaseGetTotpSecret, "get totp secret from database failed")
	VerifyOtpCodeError            = errno2.New(VerifyOtpCode, "verify code with secret failed")
	DatabaseUpdateTotpStatusError = errno2.New(DatabaseUpdateTotpStatus, "update totp status in database failed")
)
