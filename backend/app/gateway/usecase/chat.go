package usecase

import (
	"context"

	"github.com/hertz-contrib/websocket"

	"github.com/mutezebra/tiktok/app/gateway/domain/model"
	"github.com/mutezebra/tiktok/app/gateway/domain/repository"
	chat "github.com/mutezebra/tiktok/app/gateway/domain/service"
	"github.com/mutezebra/tiktok/app/gateway/usecase/pack"
)

func ChatHandler(ctx context.Context, from, to int64, repo repository.ChatRepository) func(conn *websocket.Conn) {
	srv := chat.DefaultService(repo, true)
	return func(conn *websocket.Conn) {
		client := srv.NewClient(from, to, conn)
		if err := client.Register(ctx); err != nil {
			_ = pack.ReturnError(model.ChatRegisterError, err)
			return
		}

		client.Read()
		client.Read()
		client.Write()
	}
}
