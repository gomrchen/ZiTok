package rpc

import (
	"context"
	"fmt"

	"github.com/cloudwego/kitex/client"
	"github.com/cloudwego/kitex/client/streamclient"
	"github.com/cloudwego/kitex/pkg/transmeta"
	"github.com/cloudwego/kitex/transport"

	"github.com/mutezebra/tiktok/app/gateway/config"
	"github.com/mutezebra/tiktok/app/gateway/domain/model"
	"github.com/mutezebra/tiktok/pkg/constants"
	"github.com/mutezebra/tiktok/pkg/errno"
	"github.com/mutezebra/tiktok/pkg/inject"
	"github.com/mutezebra/tiktok/pkg/kitex_gen/api/interaction/interactionservice"
	"github.com/mutezebra/tiktok/pkg/kitex_gen/api/relation/relationservice"
	"github.com/mutezebra/tiktok/pkg/kitex_gen/api/user/userservice"
	"github.com/mutezebra/tiktok/pkg/kitex_gen/api/video/videoservice"
	"github.com/mutezebra/tiktok/pkg/log"
	"github.com/mutezebra/tiktok/pkg/trace"
)

var (
	err  error
	Conf *config.Config

	Resolver          *inject.Resolver
	UserClient        userservice.Client
	VideoClient       videoservice.Client
	VideoStreamClient videoservice.StreamClient
	InteractionClient interactionservice.Client
	RelationClient    relationservice.Client
)

func Init() {
	Conf = config.Conf
	Resolver, err = inject.NewResolver(Conf.Etcd.Endpoint)
	if err != nil {
		log.LogrusObj.Panic(err)
	}

	initClient(constants.UserServiceName)
	initClient(constants.VideoServiceName)
	initClient(constants.InteractionServiceName)
	initClient(constants.RelationServiceName)
}

func initClient(serviceName string) {
	switch serviceName {
	case constants.UserServiceName:
		UserClient = userservice.MustNewClient(serviceName,
			client.WithHostPorts(discovery(serviceName)[0]),
			client.WithTransportProtocol(transport.TTHeader),
			client.WithMetaHandler(transmeta.ClientTTHeaderHandler),
			client.WithMiddleware(trace.ClientTraceMiddleware("gateway-userClient")),
		)
	case constants.VideoServiceName:
		VideoClient = videoservice.MustNewClient(serviceName,
			client.WithHostPorts(discovery(serviceName)...),
			client.WithTransportProtocol(transport.TTHeader),
			client.WithMetaHandler(transmeta.ClientTTHeaderHandler),
			client.WithMiddleware(trace.ClientTraceMiddleware("gateway-videoClient")))
		VideoStreamClient = videoservice.MustNewStreamClient(serviceName,
			streamclient.WithHostPorts(discovery(serviceName)...),
			streamclient.WithMetaHandler(transmeta.ClientTTHeaderHandler),
			streamclient.WithMiddleware(trace.ClientTraceMiddleware("gateway-videoStreamClient")))
	case constants.InteractionServiceName:
		InteractionClient = interactionservice.MustNewClient(serviceName,
			client.WithHostPorts(discovery(serviceName)...),
			client.WithTransportProtocol(transport.TTHeader),
			client.WithMetaHandler(transmeta.ClientTTHeaderHandler),
			client.WithMiddleware(trace.ClientTraceMiddleware("gateway-interactionClient")))
	case constants.RelationServiceName:
		RelationClient = relationservice.MustNewClient(serviceName,
			client.WithHostPorts(discovery(serviceName)...),
			client.WithTransportProtocol(transport.TTHeader),
			client.WithMetaHandler(transmeta.ClientTTHeaderHandler),
			client.WithMiddleware(trace.ClientTraceMiddleware("gateway-relationClient")))
	}
}

func discovery(serviceName string) []string {
	prefix := Conf.Etcd.ServicePrefix + Conf.Service[serviceName].ServiceName
	addr, err := Resolver.ResolveWithPrefix(context.Background(), prefix)
	if err != nil {
		log.LogrusObj.Panic(err)
	}
	log.LogrusObj.Infof("get the %s service address %s", serviceName, addr[0])
	return addr
}

func lostConnect(v any, service string) errno.Errno {
	if v != nil {
		return nil
	}
	return errno.New(model.InternalServerError, fmt.Sprintf("%s service lost", service))
}
