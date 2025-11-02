package rpc

import (
	"context"
	"io"

	idl "github.com/mutezebra/tiktok/pkg/kitex_gen/api/video"
)

func VideoFeed(ctx context.Context, req *idl.VideoFeedReq, ch chan []byte) (err error) {
	stream, err := VideoStreamClient.VideoFeed(ctx, req)
	if err != nil {
		return err
	}
	var i int
	resp := new(idl.VideoFeedResp)
	for {
		resp, err = stream.Recv()
		if err == io.EOF {
			err = nil
			break
		} else if err != nil {
			break
		}
		ch <- resp.Video
		i++
	}

	ch <- nil
	return err
}

func PublishVideo(ctx context.Context, req *idl.PublishVideoReq) (r *idl.PublishVideoResp, err error) {
	r, err = VideoClient.PublishVideo(ctx, req)
	return r, err
}

func GetVideoList(ctx context.Context, req *idl.GetVideoListReq) (r *idl.GetVideoListResp, err error) {
	r, err = VideoClient.GetVideoList(ctx, req)
	return r, err
}

func GetVideoPopular(ctx context.Context, req *idl.GetVideoPopularReq) (r *idl.GetVideoPopularResp, err error) {
	r, err = VideoClient.GetVideoPopular(ctx, req)
	return r, err
}

func SearchVideo(ctx context.Context, req *idl.SearchVideoReq) (r *idl.SearchVideoResp, err error) {
	r, err = VideoClient.SearchVideo(ctx, req)
	return r, err
}
