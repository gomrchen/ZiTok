package main

import (
	"context"
	"log"
	"net/http"
	_ "net/http/pprof"

	"github.com/cloudwego/hertz/pkg/app/server"
	"github.com/yxrxy/videoHub/app/gateway/commerce"
	"github.com/yxrxy/videoHub/app/gateway/drama"
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
		// 直接硬编码请求体大小上限为 100MB（单位：字节）
		server.WithMaxRequestBodySize(100<<20),
	)

	h.NoHijackConnPool = true

	h.Use(
		mw.CORS(),
	)

	router.RegisterWebSocket(h)

	router.GeneratedRegister(h)
	router.RegisterDramaRoutes(h)
	router.RegisterFeedRoutes(h)
	router.RegisterLogoutRoute(h)
	router.RegisterCommerceRoutes(h)
	router.RegisterAdminRoutes(h)
	router.RegisterEpisodeInteractRoutes(h)
	router.RegisterNotesGone(h)
	router.RegisterStaticRoutes(h)

	go func() {
		if err := drama.EnsureSeed(); err != nil {
			log.Printf("[gateway] drama seed: %v", err)
		}
		if err := commerce.EnsureAdminSeed(); err != nil {
			log.Printf("[gateway] admin seed: %v", err)
		}
	}()

	h.Spin()
}
