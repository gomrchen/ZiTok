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
	"github.com/yxrxy/videoHub/app/commerce"
	commercehandler "github.com/yxrxy/videoHub/app/commerce/handler"
	"github.com/yxrxy/videoHub/config"
	"github.com/yxrxy/videoHub/kitex_gen/commerce/commerceservice"
	"github.com/yxrxy/videoHub/pkg/base"
	"github.com/yxrxy/videoHub/pkg/middleware"
)

func init() {
	config.Init("commerce")
}

func main() {
	go func() { _ = http.ListenAndServe("0.0.0.0:6065", nil) }()

	r, err := etcd.NewEtcdRegistry([]string{config.Etcd.Addr})
	if err != nil {
		log.Fatalf("Commerce: etcd registry failed: %v", err)
	}
	addr, err := net.ResolveTCPAddr("tcp", config.Commerce.RPCAddr)
	if err != nil {
		log.Fatalf("Commerce: resolve addr failed: %v", err)
	}
	p := base.TelemetryProvider("CommerceService", config.Otel.CollectorAddr)
	defer func() { _ = p.Shutdown(context.Background()) }()

	go func() {
		if err := commerce.EnsureAdminSeed(); err != nil {
			log.Printf("Admin seed: %v", err)
		}
	}()

	svr := commerceservice.NewServer(
		commercehandler.New(),
		server.WithSuite(tracing.NewServerSuite()),
		server.WithServerBasicInfo(&rpcinfo.EndpointBasicInfo{ServiceName: "CommerceService"}),
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
		log.Printf("Commerce: run failed: %v", err)
	}
}
