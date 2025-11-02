package chat

import (
	"context"
	"fmt"
	"time"

	"github.com/cloudwego/hertz/pkg/common/json"
	"github.com/hertz-contrib/websocket"
	"github.com/pkg/errors"

	"github.com/mutezebra/tiktok/pkg/log"
)

type Client struct {
	srv     *Service
	From    int64
	To      int64
	Channel chan []byte
	Conn    *websocket.Conn
}

func (c *Client) Register(ctx context.Context) error {
	return c.srv.Register(ctx, c)
}

func (c *Client) Unregister() error {
	return c.srv.Unregister(c)
}

func (c *Client) Read() {
	go func(c *Client) {
		defer func() {
			if err := c.Unregister(); err != nil {
				log.LogrusObj.Error(err)
			}
		}()
		for {
			mt, data, err := c.Conn.ReadMessage()
			if err != nil {
				var e *websocket.CloseError
				if errors.As(err, &e) && e.Code == websocket.CloseNormalClosure {
					break
				}

				log.LogrusObj.Error(errors.Wrap(err, "websocket conn read failed"))
				break
			}

			switch mt {
			case websocket.CloseMessage:
				break
			case websocket.TextMessage:
				var msg Message
				if err = json.Unmarshal(data, &msg); err != nil {
					log.LogrusObj.Error(errors.Wrap(err, "json unmarshal failed"))

					_ = c.srv.WriteToConn([]byte("Manager: you message format is wrong"), c.From)
					continue
				}
				msg.From = c.From
				msg.To = c.To
				msg.CreateAt = time.Now().Unix()

				if err = c.srv.SendMsg(&msg); err != nil {
					log.LogrusObj.Error(err)
					break
				}
				continue

			default:
				if err = c.Conn.WriteMessage(websocket.CloseMessage, []byte("closed")); err != nil {
					log.LogrusObj.Error(err)
				}
			}
		}
	}(c)
}

func (c *Client) Write() {
	for {
		data, ok := <-c.Channel
		if ok {
			if err := c.Conn.WriteMessage(websocket.TextMessage, data); err != nil {
				log.LogrusObj.Error(fmt.Errorf("websocket conn write failed,cause: %v", err))
			}
		} else {
			break
		}
	}
}
