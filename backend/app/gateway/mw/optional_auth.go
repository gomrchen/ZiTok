package mw

import (
	"context"

	"github.com/cloudwego/hertz/pkg/app"
	pkgcontext "github.com/yxrxy/videoHub/pkg/base/context"
	"github.com/yxrxy/videoHub/pkg/jwt"
)

// OptionalAuth 有合法 token 则写入 userID，否则继续（游客）。
func OptionalAuth() app.HandlerFunc {
	return func(ctx context.Context, c *app.RequestContext) {
		token := string(c.GetHeader("Authorization"))
		if token == "" {
			c.Next(ctx)
			return
		}
		if len(token) > 7 && token[:7] == "Bearer " {
			token = token[7:]
		}
		claims, err := jwt.ParseToken(token)
		if err == nil && claims != nil {
			ctx = pkgcontext.WithUserID(ctx, claims.UserID)
			ctx = pkgcontext.SetStreamUserID(ctx, claims.UserID)
		}
		c.Next(ctx)
	}
}
