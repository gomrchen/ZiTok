package main

import (
	"context"
	"net"

	"github.com/cloudwego/kitex/pkg/rpcinfo"
	"github.com/cloudwego/kitex/pkg/transmeta"
	"github.com/cloudwego/kitex/server"

	"github.com/mutezebra/tiktok/app/interaction/cmd/pack"
	"github.com/mutezebra/tiktok/app/interaction/config"
	"github.com/mutezebra/tiktok/app/interaction/interface/persistence/database"
	"github.com/mutezebra/tiktok/pkg/constants"
	"github.com/mutezebra/tiktok/pkg/inject"
	"github.com/mutezebra/tiktok/pkg/kitex_gen/api/interaction/interactionservice"
	"github.com/mutezebra/tiktok/pkg/log"
	"github.com/mutezebra/tiktok/pkg/trace"
)

func main() {
	InteractionInit()
	registry := inject.NewRegistry(pack.InteractionRegistry())
	defer registry.Close()
	registry.MustRegister(context.Background())

	addr, _ := net.ResolveTCPAddr("tcp", config.Conf.Service[constants.InteractionServiceName].Address)
	srv := interactionservice.NewServer(pack.ApplyInteraction(),
		server.WithServiceAddr(addr),
		server.WithServerBasicInfo(&rpcinfo.EndpointBasicInfo{ServiceName: constants.InteractionServiceName}),
		server.WithMetaHandler(transmeta.ServerTTHeaderHandler),
		server.WithMiddleware(trace.ServerTraceMiddleware("interaction")),
	)

	if err := srv.Run(); err != nil {
		log.LogrusObj.Panic(err)
	}
}

func InteractionInit() {
	config.InitConfig()
	log.InitLog(config.Conf.System.Status, config.Conf.System.OS)
	database.InitMysql()
}
