package constants

import "time"

const (
	GatewayServiceKey         = "gateway"
	GatewayExitWaitTime       = 5 * time.Second
	GatewayMaxRequestBodySize = 100 * MB

	HeaderUserIdKey           = "User-ID"
	HeaderUserNameKey         = "User-Name"
	HeaderTokenUpdateCountKey = "Update-Token-Count"
	HeaderAccessTokenKey      = "Access-Token"
	HeaderRefreshTokenKey     = "Refresh-Token"

	FormUserAvatarKey = "avatar"

	FormVideoKey      = "video"
	FormVideoCoverKey = "cover"

	SentinelThreshold        = 100
	SentinelStatIntervalInMs = 1000
)
