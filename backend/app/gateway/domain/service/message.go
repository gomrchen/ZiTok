package chat

import (
	"time"

	"github.com/mutezebra/tiktok/app/gateway/domain/service/message"

	"github.com/mutezebra/tiktok/app/gateway/domain/repository"
	"github.com/mutezebra/tiktok/pkg/constants"
)

type Message struct {
	*message.Message
}

const (
	ContentEmptyError = "content should not be empty"
	ContentNotEmpty   = "content should be empty"
	PageNumError      = "page_num should not smaller than 1"
	PageSizeError     = "page_size should not smaller than 1"
	TimeStartError    = "time_start format is wrong,eg: 2006-01-02 15:04:05"
	TimeEndError      = "time_end format is wrong,eg: 2006-01-02 15:04:05"

	UnSupportedType = "unsupported msg type"
)

// CheckMessageParams check the message params
func (m *Message) CheckMessageParams() (result string) {
	switch m.MsgType {
	case constants.ChatTextMessage:
		if m.Content == "" {
			return ContentEmptyError
		}

	case constants.HistoryChatMessage:
		if m.PageNum < 1 {
			return PageNumError
		}
		if m.PageSize < 1 {
			return PageSizeError
		}
		if m.Content != "" {
			return ContentNotEmpty
		}

		var t time.Time
		var err error

		if t, err = time.Parse("2006-01-02 15:04:05", m.TimeStart); err != nil {
			return TimeStartError
		}
		m.UTimeSince = t.Unix()

		if t, err = time.Parse("2006-01-02 15:04:05", m.TimeEnd); err != nil {
			return TimeEndError
		}
		m.UTimeEnd = t.Unix()

	case constants.NotReadMessage:

	default:
		return UnSupportedType
	}

	return ""
}

// buildHistoryQueryReq build the msg history query req for repository
func (m *Message) buildHistoryQueryReq() *repository.HistoryQueryReq {
	return &repository.HistoryQueryReq{
		From:     m.From,
		To:       m.To,
		PageNum:  m.PageNum,
		PageSize: int8(m.PageSize),
		Start:    m.UTimeSince,
		End:      m.UTimeEnd,
	}
}

// buildRepoMessage convert the message to repository message
func (m *Message) buildRepoMessage() *repository.Message {
	return &repository.Message{
		UID:        m.From,
		ReceiverID: m.To,
		Content:    m.Content,
		HaveRead:   m.HaveRead,
		CreateAt:   m.CreateAt,
	}
}
