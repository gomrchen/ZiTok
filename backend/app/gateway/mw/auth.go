package mw

import (
	"context"
	"log"

	"github.com/cloudwego/hertz/pkg/app"
	"github.com/yxrxy/videoHub/app/gateway/pack"
	"github.com/yxrxy/videoHub/config"
	metainfoContext "github.com/yxrxy/videoHub/pkg/base/context"
	"github.com/yxrxy/videoHub/pkg/errno"
	"github.com/yxrxy/videoHub/pkg/jwt"
)

// 用于验证token并存储用户ID (用于 HTTP 服务)
func Auth() app.HandlerFunc {
	return func(ctx context.Context, c *app.RequestContext) {
		token := string(c.GetHeader("Authorization"))
		refresh := string(c.GetHeader("RefreshToken"))
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
		log.Printf("[AuthMiddleware] Token parsing failed for token: %s", token)
		log.Printf("[AuthMiddleware] Error details: %v", err)
		log.Printf("[AuthMiddleware] Using JWT secret: %s", config.JWT.SecretKey[:3] + "...") // 只打印密钥前3位，保护安全
		pack.RespError(c, errno.NewErrNo(errno.AuthInvalidCode, "无效的令牌"))
		c.Abort()
		return
	}

		ctx = metainfoContext.WithUserID(ctx, claims.UserID)
		ctx = metainfoContext.SetStreamUserID(ctx, claims.UserID)
		c.Header("Authorization", token)
		c.Header("RefreshToken", refresh)
		c.Next(ctx)
	}
}
