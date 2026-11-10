package router

import (
	"context"

	"github.com/cloudwego/hertz/pkg/app"
	"github.com/cloudwego/hertz/pkg/app/server"
	"github.com/yxrxy/videoHub/app/gateway/mw"
	"github.com/yxrxy/videoHub/app/gateway/pack"
)

// RegisterLogoutRoute 本地联调退出：清客户端会话为主；网关返回成功保证幂等。
// 后续若补齐 IDL/RPC 吊销 refresh_token，可在此接入。
func RegisterLogoutRoute(h *server.Hertz) {
	api := h.Group("/api/v1")
	api.POST("/user/logout", mw.Auth(), func(ctx context.Context, c *app.RequestContext) {
		pack.RespSuccess(c)
	})
}
