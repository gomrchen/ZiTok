package router

import (
	"github.com/cloudwego/hertz/pkg/app/server"
	hcommerce "github.com/yxrxy/videoHub/app/gateway/handler/commerce"
	"github.com/yxrxy/videoHub/app/gateway/mw"
)

func RegisterCommerceRoutes(h *server.Hertz) {
	api := h.Group("/api/v1/commerce", mw.Auth())
	api.GET("/wallet", hcommerce.GetWallet)
	api.GET("/ledger", hcommerce.ListLedger)
	api.POST("/unlock/episode", hcommerce.UnlockEpisode)
	api.POST("/unlock/drama", hcommerce.UnlockDrama)
	api.POST("/ad/unlock", hcommerce.AdUnlock)
	api.POST("/ad/reward", hcommerce.AdReward)
	api.POST("/topup/mock", hcommerce.MockTopup)
}
