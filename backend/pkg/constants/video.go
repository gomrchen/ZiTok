package constants

import "time"

const (
	CacheVideoViewKeyPrefix          = "video:view:"
	CacheVideoLikeKeyPrefix          = "video:likes:"
	CacheVideoPopularKey             = "video:popular:primary"
	CacheVideoPopularVideosSize      = 50
	CacheVideoPopularRefreshInterval = 5 * time.Second
	CacheVideoViewExpireTime         = 10 * time.Second
	CacheVideoLikeExpireTime         = 60 * time.Second

	DatabaseDefaultUpdateViewInterval = 5 * time.Second
)
