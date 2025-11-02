package chat

import (
	"fmt"
	"sync"

	"github.com/hertz-contrib/websocket"
)

type Manager struct {
	connMap      map[int64]*websocket.Conn
	msgChan      map[int64]chan []byte
	notOnlineTip map[int64]struct{}
	mu           sync.RWMutex
}

func (m *Manager) Register(from int64, conn *websocket.Conn, ch chan []byte) {
	m.connMap[from] = conn
	m.msgChan[from] = ch
}

func (m *Manager) Unregister(from int64) {
	m.mu.Lock()
	delete(m.connMap, from)
	delete(m.msgChan, from)
	delete(m.notOnlineTip, from)
	m.mu.Unlock()
}

// Send the only error is 'to' not online
// so for some part, you can ignore him
func (m *Manager) Send(content []byte, to int64) error {
	m.mu.RLock()
	ch, ok := m.msgChan[to]
	m.mu.RUnlock()
	if !ok {
		return NotOnlineError
	}

	ch <- content
	return nil
}

var (
	NotOnlineError = fmt.Errorf("the user is not online")
	NotOnline      = []byte("the user is not online,you can leave a message")
)

// SendNotOnlineTip will send not online tip to user,just one time
func (m *Manager) SendNotOnlineTip(to int64) {
	if _, ok := m.notOnlineTip[to]; ok {
		return
	}

	m.notOnlineTip[to] = struct{}{}
	_ = m.Send(NotOnline, to)
}
