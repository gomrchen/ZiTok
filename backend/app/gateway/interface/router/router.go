package router

import (
	"context"

	"github.com/cloudwego/hertz/pkg/app"
	"github.com/cloudwego/hertz/pkg/app/server"

	"github.com/mutezebra/tiktok/app/gateway/config"
	"github.com/mutezebra/tiktok/app/gateway/interface/handler"
	"github.com/mutezebra/tiktok/app/gateway/interface/middleware"
	"github.com/mutezebra/tiktok/pkg/constants"
)

func NewRouter() *server.Hertz {
	h := server.Default(
		server.WithHostPorts(config.Conf.Service[constants.GatewayServiceKey].Address),
		server.WithMaxRequestBodySize(constants.GatewayMaxRequestBodySize),
		server.WithExitWaitTime(constants.GatewayExitWaitTime),
	)

	h.GET("/ping", func(ctx context.Context, c *app.RequestContext) {
		c.String(200, "pong")
	})

	h.Use(middleware.TraceMiddleware(), middleware.SentinelMW())
	v1 := h.Group("/api")

	user := v1.Group("/user")
	{
		user.POST("/register", handler.UserRegisterHandler())
		user.POST("/login", handler.UserLoginHandler())

		auth := user.Group("/auth")
		auth.Use(middleware.JWT())
		{
			auth.GET("/info", handler.UserInfoHandler())
			auth.POST("/upload-avatar", handler.UploadAvatarHandler())
			auth.GET("/download-avatar", handler.DownloadAvatarHandler())
			auth.GET("/totp-qrcode", handler.TotpQRCodeHandler())
			auth.POST("/enable-totp", handler.EnableTotpHandler())
		}
	}

	video := v1.Group("/video")
	{
		video.GET("/feed", handler.VideoFeedHandler())
		video.GET("/popular", handler.VideoPopularHandler())
		video.POST("/search", handler.VideoSearchHandler())

		auth := video.Group("/auth")
		auth.Use(middleware.JWT())
		{
			auth.POST("/publish", handler.VideoPublishHandler())
			auth.GET("/list", handler.VideoListHandler())
		}
	}

	interaction := v1.Group("/interaction")
	{
		auth := interaction.Group("/auth")
		auth.Use(middleware.JWT())
		{
			auth.POST("/like", handler.LikeHandler())
			auth.POST("/dislike", handler.DisLikeHandler())
			auth.POST("/like-list", handler.LikeListHandler())
			auth.POST("/comment", handler.CommentHandler())
			auth.POST("/comment-list", handler.CommentListHandler())
			auth.POST("delete-comment", handler.DeleteCommentHandler())
		}
	}

	relation := v1.Group("/relation")
	{
		auth := relation.Group("/auth")
		auth.Use(middleware.JWT())
		{
			auth.GET("/chat", handler.ChatHandler())
			auth.POST("/follow", handler.FollowHandler())
			auth.GET("/follow-list", handler.FollowListHandler())
			auth.GET("/fans-list", handler.FansListHandler())
			auth.GET("/friends-list", handler.FriendsListHandler())
		}
	}

	return h
}
