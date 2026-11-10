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
	d.GET("/:id", mw.OptionalAuth(), hdrama.GetDramaDetail)
	d.GET("/:id/episodes", hdrama.ListEpisodes)
	d.GET("/episode/:episode_id/play", mw.OptionalAuth(), hdrama.GetPlayInfo)

	auth := d.Group("/", mw.Auth())
	auth.POST("/progress", hdrama.ReportProgress)
	auth.GET("/continue", hdrama.ContinueWatching)
	auth.GET("/favorites", hdrama.ListFavorites)
	auth.POST("/:id/favorite", hdrama.Favorite)
	auth.DELETE("/:id/favorite", hdrama.Unfavorite)
}
