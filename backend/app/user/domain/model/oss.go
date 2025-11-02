package model

import (
	"context"
)

type OSS interface {
	UploadAvatar(ctx context.Context, name string, data []byte) (err error, path string)
	DownloadAvatar(ctx context.Context, path string) string
	UploadVideo(ctx context.Context, name string, data []byte) (err error, path string)
	DownloadVideo(ctx context.Context, path string) string
	VideoFeed(name string) ([]byte, error)
	UploadVideoCover(ctx context.Context, name string, data []byte) (err error, path string)
	DownloadVideoCover(ctx context.Context, path string) string
}
