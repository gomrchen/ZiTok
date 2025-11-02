package model

// User errno codes
const (
	UserRegister           = 10000
	EncryptPassword        = 10001
	DatabaseCreateUser     = 10002
	EmailFormat            = 10003
	DatabaseUserNameExists = 10004

	UserLogin               = 10010
	GetPasswordFromDatabase = 10011
	CheckPassword           = 10012
	GenerateToken           = 10013

	UserInfo      = 10020
	GetUserInfo   = 10021
	GetFriendList = 10022
	GetFansList   = 10023
	GetFollowList = 10024
	GetVideoList  = 10025
	GetLikeList   = 10026

	UserUploadAvatar         = 10030
	GetAvatarName            = 10031
	VerifyAvatar             = 10032
	OssUploadAvatar          = 10033
	DatabaseUpdateUserAvatar = 10034
	OutOfLimitAvatarSize     = 10035

	DownloadAvatar        = 10040
	DatabaseGetUserAvatar = 10041
	OssDownloadAvatar     = 10042

	TotpQrCode               = 10050
	GenerateTotp             = 10051
	DatabaseUpdateTotpSecret = 10052

	EnableTotp               = 10060
	DatabaseGetTotpSecret    = 10061
	VerifyOtpCode            = 10062
	DatabaseUpdateTotpStatus = 10063
)
