package main

import (
	"context"
	"log"
	"net/http"
	_ "net/http/pprof"

	"github.com/cloudwego/hertz/pkg/app/server"
	"github.com/yxrxy/videoHub/app/gateway/mw"
	"github.com/yxrxy/videoHub/app/gateway/router"
	"github.com/yxrxy/videoHub/app/gateway/rpc"
	"github.com/yxrxy/videoHub/config"
	"github.com/yxrxy/videoHub/pkg/base"
)

func init() {
	config.Init("gateway")
	rpc.Init()
}

func main() {
	go func() {
		http.ListenAndServe("0.0.0.0:6060", nil)
	}()

	// 初始化链路追踪
	p := base.TelemetryProvider("GatewayService", config.Otel.CollectorAddr)
	defer func() {
		if err := p.Shutdown(context.Background()); err != nil {
			log.Fatalf("Gateway: shutdown telemetry provider failed, err: %v", err)
		}
	}()

	listenAddr := config.Gateway.Addr

	h := server.New(
		server.WithHostPorts(listenAddr),
		server.WithHandleMethodNotAllowed(true),
	)

	h.NoHijackConnPool = true

	h.Use(
		mw.CORS(),
	)

	router.RegisterWebSocket(h)

	router.RegisterStaticRoutes(h)
	router.GeneratedRegister(h)

	h.Spin()
}
