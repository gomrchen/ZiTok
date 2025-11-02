package main

import (
	"context"
	"net"

	"github.com/cloudwego/kitex/pkg/rpcinfo"
	"github.com/cloudwego/kitex/pkg/transmeta"
	"github.com/cloudwego/kitex/server"

	"github.com/mutezebra/tiktok/app/video/cmd/pack"
	"github.com/mutezebra/tiktok/app/video/config"
	"github.com/mutezebra/tiktok/app/video/interface/persistence/cache"
	"github.com/mutezebra/tiktok/app/video/interface/persistence/database"
	"github.com/mutezebra/tiktok/pkg/constants"
	"github.com/mutezebra/tiktok/pkg/inject"
	"github.com/mutezebra/tiktok/pkg/kitex_gen/api/video/videoservice"
	"github.com/mutezebra/tiktok/pkg/log"
	"github.com/mutezebra/tiktok/pkg/oss"
	"github.com/mutezebra/tiktok/pkg/trace"
)

func main() {
	VideoInit()
	registry := inject.NewRegistry(pack.VideoRegistry())
	defer registry.Close()
	registry.MustRegister(context.Background())

	addr, _ := net.ResolveTCPAddr("tcp", config.Conf.Service[constants.VideoServiceName].Address)
	srv := videoservice.NewServer(pack.ApplyVideo(),
		server.WithServiceAddr(addr),
		server.WithServerBasicInfo(&rpcinfo.EndpointBasicInfo{ServiceName: constants.VideoServiceName}),
		server.WithMetaHandler(transmeta.ServerTTHeaderHandler),
		server.WithMiddleware(trace.ServerTraceMiddleware(constants.VideoServiceName)),
	)

	if err := srv.Run(); err != nil {
		log.LogrusObj.Panic(err)
	}
}

func VideoInit() {
	config.InitConfig()
	log.InitLog(config.Conf.System.Status, config.Conf.System.OS)
	database.InitMysql()
	cache.InitCache()
	oss.InitOSS(config.Conf.QiNiu.AccessKey, config.Conf.QiNiu.SecretKey, config.Conf.QiNiu.Domain, config.Conf.QiNiu.Bucket)
}
