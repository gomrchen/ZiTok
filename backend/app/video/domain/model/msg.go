package model

import "github.com/mutezebra/tiktok/pkg/errno"

// Video errno msgs
var (
	VideoFeedStreamSendError = errno.New(VideoFeedStreamSend, "stream of video feed send resp failed")
	DatabaseGetVideoUrlError = errno.New(DatabaseGetVideoUrl, "database get video url failed")
	OssGetVideoFeedError     = errno.New(OssGetVideoFeed, "oss get video feed failed")
	IncrViewError            = errno.New(IncrView, "incr view failed")

	OssUploadVideoError      = errno.New(OssUploadVideo, "oss upload video failed")
	OssUploadVideoCoverError = errno.New(OssUploadVideoCover, "oss upload video cover failed")
	DatabaseCreateVideoError = errno.New(DatabaseCreateVideo, "database create video failed")
	OutOfLimitCoverSizeErrno = errno.New(OutOfLimitCoverSize, "out of limit of cover size")

	DatabaseGetVideoListError = errno.New(DatabaseGetVideoList, "database get video list failed")

	DatabaseSearchVideoError = errno.New(DatabaseSearchVideo, "database search video failed")

	DatabaseGetVideoInfoError = errno.New(DatabaseGetVideoInfo, "database get video info failed")
)
