package router

import (
	"github.com/cloudwego/hertz/pkg/app/server"
	hdrama "github.com/yxrxy/videoHub/app/gateway/handler/drama"
	"github.com/yxrxy/videoHub/app/gateway/mw"
)

func RegisterDramaRoutes(h *server.Hertz) {
	api := h.Group("/api/v1")
	d := api.Group("/drama")
	d.GET("/list", hdrama.ListDramas)
	d.GET("/feed", mw.OptionalAuth(), hdrama.GetFeed)
	d.GET("/search", hdrama.SearchDramas)
	d.GET("/episode/:episode_id/play", mw.OptionalAuth(), hdrama.GetPlayInfo)

	// 固定路径必须在 /:id 之前，避免 watching/history 被当成剧目 ID
	auth := d.Group("/", mw.Auth())
	auth.POST("/progress", hdrama.ReportProgress)
	auth.GET("/continue", hdrama.ContinueWatching)
	auth.GET("/watching", hdrama.ContinueWatching) // 别名
	auth.GET("/history", hdrama.ContinueWatching)  // 别名：进度历史
	auth.GET("/favorites", hdrama.ListFavorites)
	auth.POST("/:id/favorite", hdrama.Favorite)
	auth.DELETE("/:id/favorite", hdrama.Unfavorite)

	d.GET("/:id", mw.OptionalAuth(), hdrama.GetDramaDetail)
	d.GET("/:id/episodes", hdrama.ListEpisodes)
}
