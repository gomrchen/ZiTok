package repository

import (
	"context"

	"github.com/mutezebra/tiktok/pkg/types"
)

type Message types.Message

type ChatRepository interface {
	WhetherExistUser(ctx context.Context, uid int64) (bool, error)
	CreateMessage(ctx context.Context, msg *Message) error
	CreateMessageWithChannel(ctx context.Context, msgs chan *Message)
	ChatMessageHistory(ctx context.Context, req *HistoryQueryReq) ([]Message, error)
	NotReadMessage(ctx context.Context, uid int64, receiverID int64) ([]Message, error)
}

type HistoryQueryReq struct {
	PageSize   int8
	PageNum    int32
	Start, End int64
	From, To   int64
}
