package chat

import (
	"bytes"
	"context"
	"encoding/gob"
	"encoding/json"
	"io"
	"os"
	"os/signal"
	"sync"

	"github.com/hertz-contrib/websocket"
	"github.com/pkg/errors"

	"github.com/mutezebra/tiktok/app/gateway/domain/model"
	"github.com/mutezebra/tiktok/app/gateway/domain/repository"
	"github.com/mutezebra/tiktok/pkg/constants"
	"github.com/mutezebra/tiktok/pkg/kafka"
	"github.com/mutezebra/tiktok/pkg/log"
)

type Service struct {
	Manager *Manager
	repo    repository.ChatRepository

	mq        model.MQ
	mqReadCh  chan []byte
	mqWriteCh chan []byte

	ctx                    context.Context
	bufferPool             sync.Pool
	enableAsyncPersistence bool
}

var (
	once           sync.Once
	defaultService *Service
)

func DefaultService(repo repository.ChatRepository, enableAsyncPersistence bool) *Service {
	once.Do(func() {
		defaultService = &Service{
			Manager: &Manager{
				connMap:      make(map[int64]*websocket.Conn),
				msgChan:      make(map[int64]chan []byte),
				notOnlineTip: make(map[int64]struct{}),
			},
			repo: repo,

			mq:        &kafka.MQModel{},
			mqReadCh:  make(chan []byte, constants.ChatMQReadChSize),
			mqWriteCh: make(chan []byte, constants.ChatMQWriteChSize),

			ctx:                    context.Background(),
			bufferPool:             sync.Pool{New: func() any { return new(bytes.Buffer) }},
			enableAsyncPersistence: enableAsyncPersistence,
		}
		if defaultService.enableAsyncPersistence {
			defaultService.EnableSyncPersistence()
		}
	})
	return defaultService
}

func (s *Service) NewClient(from, to int64, conn *websocket.Conn) *Client {
	return &Client{
		srv:     s,
		From:    from,
		To:      to,
		Channel: make(chan []byte, 1),
		Conn:    conn,
	}
}

func (s *Service) Register(ctx context.Context, client *Client) error {
	exist, err := s.repo.WhetherExistUser(ctx, client.To)
	if !exist {
		return errors.WithMessage(err, "user not exist")
	}
	if err != nil {
		return err
	}

	s.Manager.Register(client.From, client.Conn, client.Channel)
	return nil
}

func (s *Service) Unregister(client *Client) error {
	err := client.Conn.Close()
	if err != nil {
		return errors.New("websocket conn close failed")
	}

	close(client.Channel)
	s.Manager.Unregister(client.From)
	return nil
}

// SendMsg if return error, the client will close the connection
func (s *Service) SendMsg(msg *Message) error {
	var err error
	switch msg.MsgType {
	case constants.ChatTextMessage:
		err = s.SendChatTextMessage(msg)

	case constants.HistoryChatMessage:
		err = s.SendHistoryChatMessage(msg)

	case constants.NotReadMessage:
		err = s.SendNotReadMessage(msg)

	default:
		return s.WriteToConn([]byte("Manager: not supported msg type"), msg.From)
	}
	return err
}

// WriteToConn the only error is 'to' not online
// so for some part, you can ignore him
func (s *Service) WriteToConn(message []byte, to int64) error {
	return s.Manager.Send(message, to)
}

// EnableSyncPersistence enable message async persistence.
// kafka consumes the Message object and sends it to the goroutine repository via a channel
func (s *Service) EnableSyncPersistence() {
	s.EnableMQ()
	go s.MessagePersistence(constants.ChatDefaultPersistenceGoroutineNum)
}

func (s *Service) SendChatTextMessage(msg *Message) error {
	var err error
	if result := msg.CheckMessageParams(); result != "" {
		_ = s.WriteToConn([]byte(result), msg.From)
		return nil
	}

	if err = s.Manager.Send([]byte(msg.Content), msg.To); errors.Is(err, NotOnlineError) {
		msg.HaveRead = false
		s.Manager.SendNotOnlineTip(msg.From)
	} else {
		msg.HaveRead = true
	}

	if s.enableAsyncPersistence {
		return s.writeMsgToMQ(msg)
	}

	err = s.StoreMessage(msg)
	if err != nil {
		return err
	}
	return nil
}

func (s *Service) SendHistoryChatMessage(msg *Message) error {
	if result := msg.CheckMessageParams(); result != "" {
		_ = s.WriteToConn([]byte(result), msg.From)
		return nil
	}

	req := msg.buildHistoryQueryReq()
	repoMessages, err := s.repo.ChatMessageHistory(s.ctx, req)
	if err != nil {
		return errors.WithMessage(err, "failed to query chat message history")
	}

	if len(repoMessages) == 0 {
		_ = s.WriteToConn([]byte("no chat history"), msg.From)
		return nil
	}

	data, err := json.Marshal(repoMessages)
	if err != nil {
		return errors.Wrap(err, "failed to marshal chat message history")
	}

	_ = s.Manager.Send(data, msg.From)
	return nil
}

func (s *Service) SendNotReadMessage(msg *Message) error {
	if result := msg.CheckMessageParams(); result != "" {
		_ = s.WriteToConn([]byte(result), msg.From)
		return nil
	}

	repoMessages, err := s.repo.NotReadMessage(s.ctx, msg.To, msg.From)
	if err != nil {
		return errors.WithMessage(err, "failed to find not read message")
	}

	if len(repoMessages) == 0 {
		_ = s.Manager.Send([]byte("no unread message"), msg.From)
		return nil
	}

	data, err := json.Marshal(repoMessages)
	if err != nil {
		return errors.Wrap(err, "failed to marshal not read messages")
	}

	_ = s.Manager.Send(data, msg.From)
	return nil
}

func (s *Service) StoreMessage(msg *Message) error {
	return s.repo.CreateMessage(s.ctx, msg.buildRepoMessage())
}

// MessagePersistence read message from mq and write to db
func (s *Service) MessagePersistence(asyncNumber int) {
	interrupt := make(chan os.Signal, 1)
	signal.Notify(interrupt, os.Interrupt)

	chs := make([]chan *repository.Message, 0, asyncNumber)
	for i := 0; i < asyncNumber; i++ {
		ch := make(chan *repository.Message, 1)
		chs = append(chs, ch)
		go func() {
			go s.repo.CreateMessageWithChannel(s.ctx, ch)
			for {
				msg, err := s.readMsgFromMQ()
				if err != nil {
					if errors.Is(err, io.EOF) {
						return
					}
					log.LogrusObj.Error(errors.WithMessage(err, "message persistence failed when read msg From mq"))
					return
				}
				repoMsg := msg.buildRepoMessage()
				ch <- repoMsg
			}
		}()
	}

	<-interrupt
	for _, ch := range chs {
		close(ch)
	}
}

// getMsgBytes format Message to bytes
func (s *Service) getMsgBytes(msg *Message) ([]byte, error) {
	buf := s.getBuffer()
	defer s.putBuffer(buf)

	enc := gob.NewEncoder(buf)
	err := enc.Encode(msg)
	if err != nil {
		return nil, errors.Wrap(err, "gob encoder encode msg failed")
	}

	return buf.Bytes(), nil
}

// getMsgFromBytes format bytes to Message
func (s *Service) getMsgFromBytes(data []byte) (*Message, error) {
	buf := s.getBuffer()
	defer s.putBuffer(buf)

	if _, err := buf.Write(data); err != nil {
		return nil, errors.Wrap(err, "failed write data To buffer")
	}

	dec := gob.NewDecoder(buf)
	msg := &Message{}
	if err := dec.Decode(msg); err != nil && err != io.EOF {
		return nil, errors.Wrap(err, "gob decoder decode msg failed")
	}

	return msg, nil
}

func (s *Service) getBuffer() *bytes.Buffer {
	buf := s.bufferPool.Get().(*bytes.Buffer)
	buf.Reset()
	return buf
}

func (s *Service) putBuffer(buf *bytes.Buffer) {
	s.bufferPool.Put(buf)
}
