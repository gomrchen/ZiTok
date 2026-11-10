package router

import (
	"context"

	"github.com/cloudwego/hertz/pkg/app"
	"github.com/cloudwego/hertz/pkg/app/server"
	"github.com/yxrxy/videoHub/app/gateway/pack"
	"github.com/yxrxy/videoHub/pkg/errno"
)

// RegisterNotesGone 笔记能力已下线，返回明确错误码。
func RegisterNotesGone(h *server.Hertz) {
	gone := func(ctx context.Context, c *app.RequestContext) {
		pack.RespError(c, errno.NewErrNo(41000, "笔记功能已下线"))
	}
	g := h.Group("/api/v1/note")
	g.Any("/*path", gone)
	g.Any("/", gone)
}
