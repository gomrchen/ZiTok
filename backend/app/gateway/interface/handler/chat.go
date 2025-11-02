package handler

import (
	"context"
	"strconv"

	"github.com/cloudwego/hertz/pkg/app"
	"github.com/hertz-contrib/websocket"

	"github.com/mutezebra/tiktok/app/gateway/domain/model"
	"github.com/mutezebra/tiktok/app/gateway/interface/pack"
	"github.com/mutezebra/tiktok/app/gateway/interface/persistence/database"
	"github.com/mutezebra/tiktok/app/gateway/usecase"
	"github.com/mutezebra/tiktok/pkg/constants"
)

func ChatHandler() app.HandlerFunc {
	upgrader := websocket.HertzUpgrader{
		CheckOrigin: func(ctx *app.RequestContext) bool {
			return true
		},
	} // use default options

	return func(ctx context.Context, c *app.RequestContext) {
		UID, _ := strconv.ParseInt(string(c.GetHeader(constants.HeaderUserIdKey)), 10, 64)

		toS := c.Query("to")
		to, err := strconv.ParseInt(toS, 10, 64)
		if err != nil {
			pack.SendFailedResponse(c, pack.ReturnError(model.InvalidParamErrno, err))
			return
		}

		err = upgrader.Upgrade(c, usecase.ChatHandler(ctx, UID, to, database.NewChatRepository()))
		if err != nil {
			pack.SendFailedResponse(c, pack.ReturnError(model.InternalServerErrorErrno, err))
		}
	}
}
