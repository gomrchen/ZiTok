package handler

import (
	"context"
	"errors"
	"strconv"

	"github.com/cloudwego/hertz/pkg/app"
	hzresp "github.com/cloudwego/hertz/pkg/protocol/http1/resp"

	"github.com/mutezebra/tiktok/app/gateway/domain/model"
	"github.com/mutezebra/tiktok/app/gateway/interface/pack"
	"github.com/mutezebra/tiktok/app/gateway/interface/rpc"
	"github.com/mutezebra/tiktok/pkg/constants"
	idl "github.com/mutezebra/tiktok/pkg/kitex_gen/api/video"
)

func VideoFeedHandler() app.HandlerFunc {
	return func(ctx context.Context, c *app.RequestContext) {
		var req idl.VideoFeedReq
		if err := c.BindAndValidate(&req); err != nil {
			pack.SendFailedResponse(c, pack.ReturnError(model.InvalidParamErrno, err))
			return
		}

		c.Header("Content-Type", "video/mp4")
		c.Header("Transfer-Encoding", "chunked")

		ch := make(chan []byte, 1)
		defer close(ch)

		go func(ch chan []byte) {
			c.Response.HijackWriter(hzresp.NewChunkedBodyWriter(&c.Response, c.GetWriter()))
			var buf []byte
			for {
				buf = <-ch
				if buf == nil {
					break
				}
				_, _ = c.Write(buf)
				_ = c.Flush()
			}
		}(ch)

		err := rpc.VideoFeed(ctx, &req, ch)
		if err != nil {
			pack.SendFailedResponse(c, err)
			return
		}
	}
}

func VideoPopularHandler() app.HandlerFunc {
	return func(ctx context.Context, c *app.RequestContext) {
		var req idl.GetVideoPopularReq

		resp, err := rpc.GetVideoPopular(ctx, &req)
		if err != nil {
			pack.SendFailedResponse(c, err)
			return
		}

		pack.SendResponse(c, resp)
	}
}

func VideoSearchHandler() app.HandlerFunc {
	return func(ctx context.Context, c *app.RequestContext) {
		var req idl.SearchVideoReq
		if err := c.BindAndValidate(&req); err != nil {
			pack.SendFailedResponse(c, pack.ReturnError(model.InvalidParamErrno, err))
			return
		}

		resp, err := rpc.SearchVideo(ctx, &req)
		if err != nil {
			pack.SendFailedResponse(c, err)
			return
		}

		pack.SendResponse(c, resp)
	}
}

func VideoPublishHandler() app.HandlerFunc {
	return func(ctx context.Context, c *app.RequestContext) {
		var req idl.PublishVideoReq
		if err := c.BindAndValidate(&req); err != nil {
			pack.SendFailedResponse(c, pack.ReturnError(model.InvalidParamErrno, err))
			return
		}

		coverFileHeader, err := c.FormFile(constants.FormVideoCoverKey)
		if err != nil {
			pack.SendFailedResponse(c, pack.ReturnError(model.InternalServerErrorErrno, err))
			return
		}

		req.SetCoverName(&coverFileHeader.Filename)

		if coverFileHeader.Size > constants.MB*6 {
			pack.SendFailedResponse(c, pack.ReturnError(model.OutOfLimitCoverSizeErrno, nil))
			return
		}

		coverFile, err := coverFileHeader.Open()
		if err != nil {
			pack.SendFailedResponse(c, pack.ReturnError(model.InternalServerErrorErrno, err))
			return
		}

		req.Cover = make([]byte, coverFileHeader.Size)
		_, err = coverFile.Read(req.Cover)
		if err != nil {
			pack.SendFailedResponse(c, pack.ReturnError(model.InternalServerErrorErrno, err))
			return
		}

		videoFileHeader, err := c.FormFile(constants.FormVideoKey)
		if err != nil {
			pack.SendFailedResponse(c, pack.ReturnError(model.InternalServerErrorErrno, err))
			return
		}

		req.SetVideoName(&videoFileHeader.Filename)

		videoFile, err := videoFileHeader.Open()
		if err != nil {
			pack.SendFailedResponse(c, pack.ReturnError(model.InternalServerErrorErrno, err))
			return
		}

		req.Video = make([]byte, videoFileHeader.Size)
		_, err = videoFile.Read(req.Video)
		if err != nil {
			pack.SendFailedResponse(c, pack.ReturnError(model.InternalServerErrorErrno, err))
			return
		}

		id, _ := strconv.ParseInt(string(c.GetHeader(constants.HeaderUserIdKey)), 10, 64)
		req.SetUID(&id)

		resp, err := rpc.PublishVideo(ctx, &req)
		if err != nil {
			pack.SendFailedResponse(c, err)
			return
		}

		pack.SendResponse(c, resp)
	}
}

func VideoListHandler() app.HandlerFunc {
	return func(ctx context.Context, c *app.RequestContext) {
		var req idl.GetVideoListReq
		if err := c.BindAndValidate(&req); err != nil {
			pack.SendFailedResponse(c, pack.ReturnError(model.InvalidParamErrno, err))
			return
		}

		if req.GetPages() < 1 {
			pack.SendFailedResponse(c, errors.New("pages must begin with 1"))
			return
		}

		if req.GetSize() > 20 || req.GetSize() < 1 {
			pack.SendFailedResponse(c, errors.New("size must within 1 and 20"))
			return
		}

		id, _ := strconv.ParseInt(string(c.GetHeader(constants.HeaderUserIdKey)), 10, 64)
		req.SetUID(&id)

		resp, err := rpc.GetVideoList(ctx, &req)
		if err != nil {
			pack.SendFailedResponse(c, err)
			return
		}

		pack.SendResponse(c, resp)
	}
}
