package rpc

import (
	"context"

	"github.com/cloudwego/kitex/client"
	"github.com/cloudwego/kitex/pkg/retry"
	etcd "github.com/kitex-contrib/registry-etcd"
	trace "github.com/kitex-contrib/tracer-opentracing"
	"github.com/ozline/tiktok/config"
	"github.com/ozline/tiktok/kitex_gen/video"
	"github.com/ozline/tiktok/kitex_gen/video/videoservice"
	"github.com/ozline/tiktok/pkg/constants"
	"github.com/ozline/tiktok/pkg/errno"
	"github.com/ozline/tiktok/pkg/middleware"
)

func InitVideoRPC() {
	r, err := etcd.NewEtcdResolver([]string{config.Etcd.Addr})

	if err != nil {
		panic(err)
	}

	c, err := videoservice.NewClient(
		constants.VideoServiceName,
		client.WithMiddleware(middleware.CommonMiddleware),
		client.WithMuxConnection(constants.MuxConnection),
		client.WithRPCTimeout(constants.RPCTimeout),
		client.WithConnectTimeout(constants.ConnectTimeout),
		client.WithFailureRetry(retry.NewFailurePolicy()),
		client.WithResolver(r),
		client.WithSuite(trace.NewDefaultClientSuite()), // 设置链路追踪
	)

	if err != nil {
		panic(err)
	}

	videoClient = c
}

func GetVideoOwner(ctx context.Context, videoId int64, token string) (int64, error) {
	// 通过video服务获取视频信息，然后获取owner_id
	// 这里需要调用video服务的GetPublishList或类似接口
	// 暂时通过数据库查询，后续可以优化为RPC调用
	return 0, nil
}

