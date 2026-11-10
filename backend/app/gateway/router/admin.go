package router

import (
	"github.com/cloudwego/hertz/pkg/app/server"
	hadmin "github.com/yxrxy/videoHub/app/gateway/handler/admin"
	"github.com/yxrxy/videoHub/app/gateway/mw"
)

func RegisterAdminRoutes(h *server.Hertz) {
	api := h.Group("/api/v1/admin")
	api.POST("/login", hadmin.Login)

	auth := api.Group("/", mw.AdminAuth())
	auth.GET("/stats", hadmin.Stats)
	auth.GET("/dramas", hadmin.ListDramas)
	auth.POST("/dramas", hadmin.CreateDrama)
	auth.PUT("/dramas/:id", hadmin.UpdateDrama)
	auth.POST("/dramas/:id/offline", hadmin.OfflineDrama)
	auth.GET("/dramas/:id/episodes", hadmin.ListEpisodes)
	auth.POST("/dramas/:id/episodes", hadmin.CreateEpisode)
	auth.POST("/dramas/:id/episodes/upload", hadmin.UploadEpisodeVideo)
	auth.PUT("/episodes/:episode_id", hadmin.UpdateEpisode)
	auth.POST("/wallet/adjust", hadmin.AdjustWallet)
}
