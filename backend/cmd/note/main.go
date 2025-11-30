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
    "github.com/yxrxy/videoHub/app/notes"
    "github.com/yxrxy/videoHub/config"
    "github.com/yxrxy/videoHub/kitex_gen/notes/notesservice"
    "github.com/yxrxy/videoHub/pkg/base"
)

func init() {
    config.Init("note")
}

func main() {
    go func() {
        http.ListenAndServe("0.0.0.0:6061", nil)
    }()
    r, err := etcd.NewEtcdRegistry([]string{config.Etcd.Addr})
    if err != nil {
        log.Fatalf("Note: new etcd registry failed, err: %v", err)
    }
    listenAddr := config.Note.Name
    if config.Note != nil && config.Note.RPCAddr != "" { // fallback sample if needed
        listenAddr = config.Note.RPCAddr
    }
    if config.Note != nil && config.Note.RPCAddr != "" {
        listenAddr = config.Note.RPCAddr
    }
    if listenAddr == "" {
        listenAddr = "0.0.0.0:8894"
    }
    addr, err := net.ResolveTCPAddr("tcp", listenAddr)
    if err != nil {
        log.Fatalf("Note: resolve tcp addr failed, err: %v", err)
    }

    p := base.TelemetryProvider("NoteService", config.Otel.CollectorAddr)
    defer func() {
        if err := p.Shutdown(context.Background()); err != nil {
            log.Fatalf("Note: shutdown telemetry provider failed, err: %v", err)
        }
    }()

    svr := notesservice.NewServer(
        notes.InjectHandlers(),
        server.WithSuite(tracing.NewServerSuite()),
        server.WithServerBasicInfo(&rpcinfo.EndpointBasicInfo{ServiceName: "NoteService"}),
        server.WithMuxTransport(),
        server.WithServiceAddr(addr),
        server.WithRegistry(r),
        server.WithLimit(&limit.Option{MaxConnections: int(config.Server.MaxConnections), MaxQPS: int(config.Server.MaxQPS)}),
    )

    if err := svr.Run(); err != nil {
        log.Fatalf("Note: run server failed, err: %v", err)
    }
}
