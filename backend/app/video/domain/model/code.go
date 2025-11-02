package model

// Video errno codes
const (
	VideoFeedStreamSend = 20000
	DatabaseGetVideoUrl = 20001
	OssGetVideoFeed     = 20002
	IncrView            = 20003

	OssUploadVideo      = 20010
	OssUploadVideoCover = 20011
	DatabaseCreateVideo = 20012
	OutOfLimitCoverSize = 20013

	DatabaseGetVideoList = 20020

	DatabaseSearchVideo = 20030

	DatabaseGetVideoInfo = 20040
)
