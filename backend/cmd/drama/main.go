package main

import (
	"context"
	"log"
	"net"
	"net/http"
	_ "net/http/pprof"

	"github.com/cloudwego/kitex/pkg/limit"
	"github.com/cloudwego/kitex/pkg/rpcinfo"
	"github.com/cloudwego/kitex/server"
	"github.com/kitex-contrib/obs-opentelemetry/tracing"
	etcd "github.com/kitex-contrib/registry-etcd"
	_ "github.com/yxrxy/videoHub/app/commerce" // wire HasUnlock
	dramahandler "github.com/yxrxy/videoHub/app/drama/handler"
	"github.com/yxrxy/videoHub/app/drama"
	"github.com/yxrxy/videoHub/config"
	"github.com/yxrxy/videoHub/kitex_gen/drama/dramaservice"
	"github.com/yxrxy/videoHub/pkg/base"
	"github.com/yxrxy/videoHub/pkg/middleware"
)

func init() {
	config.Init("drama")
}

func main() {
	go func() { _ = http.ListenAndServe("0.0.0.0:6064", nil) }()

	r, err := etcd.NewEtcdRegistry([]string{config.Etcd.Addr})
	if err != nil {
		log.Fatalf("Drama: etcd registry failed: %v", err)
	}
	addr, err := net.ResolveTCPAddr("tcp", config.Drama.RPCAddr)
	if err != nil {
		log.Fatalf("Drama: resolve addr failed: %v", err)
	}
	p := base.TelemetryProvider("DramaService", config.Otel.CollectorAddr)
	defer func() { _ = p.Shutdown(context.Background()) }()

	go func() {
		if err := drama.EnsureSeed(); err != nil {
			log.Printf("Drama seed: %v", err)
		}
	}()

	svr := dramaservice.NewServer(
		dramahandler.New(),
		server.WithSuite(tracing.NewServerSuite()),
		server.WithServerBasicInfo(&rpcinfo.EndpointBasicInfo{ServiceName: "DramaService"}),
		server.WithMuxTransport(),
		server.WithServiceAddr(addr),
		server.WithRegistry(r),
		server.WithLimit(&limit.Option{
			MaxConnections: int(config.Server.MaxConnections),
			MaxQPS:         int(config.Server.MaxQPS),
		}),
		server.WithMiddleware(middleware.ErrorLog()),
		server.WithMiddleware(middleware.Metrics()),
		server.WithMiddleware(middleware.Respond()),
	)
	if err = svr.Run(); err != nil {
		log.Printf("Drama: run failed: %v", err)
	}
}
