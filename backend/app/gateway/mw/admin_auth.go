package mw

import (
	"context"

	"github.com/cloudwego/hertz/pkg/app"
	"github.com/yxrxy/videoHub/app/gateway/commerce"
	"github.com/yxrxy/videoHub/app/gateway/pack"
	pkgcontext "github.com/yxrxy/videoHub/pkg/base/context"
	"github.com/yxrxy/videoHub/pkg/errno"
	"github.com/yxrxy/videoHub/pkg/jwt"
)

// AdminAuth 校验运营后台 JWT，并确认 admin_user 存在。
func AdminAuth() app.HandlerFunc {
	return func(ctx context.Context, c *app.RequestContext) {
		token := string(c.GetHeader("Authorization"))
		if token == "" {
			pack.RespError(c, errno.NewErrNo(errno.AuthNoTokenCode, "未提供令牌"))
			c.Abort()
			return
		}
		if len(token) > 7 && token[:7] == "Bearer " {
			token = token[7:]
		}
		claims, err := jwt.ParseToken(token)
		if err != nil {
			pack.RespError(c, errno.NewErrNo(errno.AuthInvalidCode, "无效的令牌"))
			c.Abort()
			return
		}
		d, err := commerce.DB()
		if err != nil {
			pack.RespError(c, err)
			c.Abort()
			return
		}
		var n int64
		if err := d.Table("admin_user").Where("id = ?", claims.UserID).Count(&n).Error; err != nil || n == 0 {
			pack.RespError(c, errno.NewErrNo(errno.AuthInvalidCode, "非运营账号"))
			c.Abort()
			return
		}
		ctx = pkgcontext.WithUserID(ctx, claims.UserID)
		c.Next(ctx)
	}
}
