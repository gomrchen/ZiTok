package repository

import (
	"context"

	"github.com/mutezebra/tiktok/pkg/types"
)

type Video types.Video

type VideoRepository interface {
	CreateVideo(ctx context.Context, video *Video) (int64, error)
	GetVideoInfo(ctx context.Context, vid int64) (*Video, error)
	GetVideosInfo(ctx context.Context, vid []int64) ([]Video, error)
	GetVideoListByID(ctx context.Context, uid int64, page int, size int) ([]Video, error)
	SearchVideo(ctx context.Context, content string, page int, size int) ([]Video, error)
	GetVideoUrl(ctx context.Context, vid int64) (string, error)
	GetValByColumn(ctx context.Context, vid int64, column string) (string, error)
	UpdateViews(kvs map[int64]int32)
	GetVideoViews(ctx context.Context, vid int64) (int32, error)
}
