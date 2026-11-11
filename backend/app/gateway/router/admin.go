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
	auth.GET("/categories", hadmin.ListCategories)
	auth.POST("/categories", hadmin.CreateCategory)
	auth.POST("/categories/rename", hadmin.RenameCategory)
	auth.DELETE("/categories", hadmin.DeleteCategory)
	auth.POST("/categories/delete", hadmin.DeleteCategory)
	auth.GET("/dramas", hadmin.ListDramas)
	auth.GET("/dramas/top", hadmin.ListTopDramas)
	auth.POST("/dramas", hadmin.CreateDrama)
	auth.POST("/dramas/batch-status", hadmin.BatchDramaStatus)
	auth.POST("/dramas/batch-restore", hadmin.BatchRestoreDramas)
	auth.POST("/dramas/batch-purge", hadmin.BatchHardDeleteDramas)
	auth.GET("/dramas/:id", hadmin.GetDramaDetail)
	auth.GET("/dramas/:id/stats", hadmin.GetDramaStats)
	auth.PUT("/dramas/:id", hadmin.UpdateDrama)
	auth.DELETE("/dramas/:id", hadmin.DeleteDrama)
	auth.DELETE("/dramas/:id/purge", hadmin.HardDeleteDrama)
	auth.POST("/dramas/:id/offline", hadmin.OfflineDrama)
	auth.POST("/dramas/:id/online", hadmin.OnlineDrama)
	auth.POST("/dramas/:id/restore", hadmin.RestoreDrama)
	auth.POST("/dramas/:id/pricing", hadmin.BatchEpisodePricing)
	auth.GET("/dramas/:id/episodes", hadmin.ListEpisodes)
	auth.POST("/dramas/:id/episodes", hadmin.CreateEpisode)
	auth.POST("/dramas/:id/episodes/upload", hadmin.UploadEpisodeVideo)
	auth.PUT("/episodes/:episode_id", hadmin.UpdateEpisode)
	auth.POST("/episodes/:episode_id/reorder", hadmin.SetEpisodeNo)
	auth.DELETE("/episodes/:episode_id", hadmin.DeleteEpisode)
	auth.POST("/covers/upload", hadmin.UploadCover)
	auth.POST("/wallet/adjust", hadmin.AdjustWallet)
	auth.POST("/wallet/topup", hadmin.AdminTopup)
	auth.GET("/wallet/:user_id", hadmin.GetWallet)
	auth.GET("/users", hadmin.ListUsers)
	auth.GET("/users/search", hadmin.SearchUsers)
	auth.GET("/users/:user_id", hadmin.GetUserDetail)
	auth.GET("/ledger", hadmin.ListLedger)
	auth.GET("/topups", hadmin.ListTopups)
	auth.GET("/unlocks", hadmin.ListUnlocks)
	auth.POST("/unlocks/grant", hadmin.GrantUnlock)
	auth.DELETE("/unlocks/:id", hadmin.RevokeUnlock)
	auth.POST("/account/password", hadmin.ChangePassword)
}
