package ws

import (
	"context"
	"encoding/json"
	"log"
	"sync"
	"time"

	"github.com/hertz-contrib/websocket"
)

// 消息类型
const (
	// 系统消息类型
	MessageTypeSystem = "system"
	// 私信消息类型
	MessageTypePrivate = "private"
	// 群聊消息类型
	MessageTypeGroup = "group"
	// 好友请求消息类型
	MessageTypeFriendRequest = "friend_request"
)

// Message WebSocket消息结构
type Message struct {
	Type      string         `json:"type"`              // 消息类型
	From      int64          `json:"from"`              // 发送者ID
	To        int64          `json:"to,omitempty"`      // 接收者ID（私信时使用）
	RoomID    int64          `json:"room_id,omitempty"` // 聊天室ID（群聊时使用）
	Content   string         `json:"content"`           // 消息内容
	Extra     map[string]any `json:"extra,omitempty"`   // 额外数据
	Timestamp int64          `json:"timestamp"`         // 时间戳
}

// Client 表示一个WebSocket客户端连接
type Client struct {
	UserID  int64           // 用户ID
	Conn    *websocket.Conn // WebSocket连接
	Rooms   map[int64]bool  // 加入的聊天室
	mu      sync.Mutex      // 保护 Rooms
	writeMu sync.Mutex      // 串行化 Conn 写，避免 concurrent write
}

// Manager 管理WebSocket连接
type Manager struct {
	clients    map[int64]*Client          // 用户ID -> 客户端连接
	roomMap    map[int64]map[*Client]bool // 聊天室ID -> 客户端集合
	broadcast  chan []byte                // 广播消息通道
	unregister chan *Client               // 注销客户端通道
	mutex      sync.RWMutex               // 保护 clients 和 roomMap 的互斥锁
}

// NewManager 创建一个新的WebSocket管理器
func NewManager() *Manager {
	return &Manager{
		clients:    make(map[int64]*Client),
		roomMap:    make(map[int64]map[*Client]bool),
		broadcast:  make(chan []byte),
		unregister: make(chan *Client),
	}
}

// RegisterClient 注册新的WebSocket客户端
// 注意：读循环由 gateway handler 负责，这里只登记连接并启动写侧心跳。
func (m *Manager) RegisterClient(userID int64, conn *websocket.Conn) *Client {
	client := &Client{
		UserID: userID,
		Conn:   conn,
		Rooms:  make(map[int64]bool),
	}

	m.mutex.Lock()
	if old, ok := m.clients[userID]; ok && old != nil && old != client {
		// 同用户重连：先摘掉旧连接，避免旧 defer 误删新客户端
		for roomID := range old.Rooms {
			if room, exists := m.roomMap[roomID]; exists {
				delete(room, old)
				if len(room) == 0 {
					delete(m.roomMap, roomID)
				}
			}
		}
		delete(m.clients, userID)
		go func(c *Client) {
			_ = c.Conn.Close()
		}(old)
	}
	m.clients[userID] = client
	m.mutex.Unlock()

	go client.WritePump()

	// 发送欢迎消息
	welcomeMsg := &Message{
		Type:      MessageTypeSystem,
		Content:   "欢迎加入聊天系统",
		Timestamp: time.Now().Unix(),
	}
	data, _ := json.Marshal(welcomeMsg)
	if err := client.SendMessage(websocket.TextMessage, data); err != nil {
		log.Printf("error sending welcome message: %v", err)
	}
	return client
}

// UnregisterClient 仅当 map 中仍是该连接时才注销（防重连竞态）
func (m *Manager) UnregisterClient(client *Client) {
	if client == nil {
		return
	}
	m.mutex.Lock()
	defer m.mutex.Unlock()
	cur, ok := m.clients[client.UserID]
	if !ok || cur != client {
		return
	}
	for roomID := range client.Rooms {
		if room, exists := m.roomMap[roomID]; exists {
			delete(room, client)
			if len(room) == 0 {
				delete(m.roomMap, roomID)
			}
		}
	}
	delete(m.clients, client.UserID)
}

// Start 启动WebSocket管理器
func (m *Manager) Start(ctx context.Context) {
	for {
		select {
		case client := <-m.unregister:
			m.UnregisterClient(client)

		case message := <-m.broadcast:
			m.mutex.RLock()
			for _, client := range m.clients {
				if err := client.SendMessage(websocket.TextMessage, message); err != nil {
					m.unregister <- client
					log.Printf("error broadcasting message: %v", err)
				}
			}
			m.mutex.RUnlock()

		case <-ctx.Done():
			// 关闭所有连接
			m.mutex.Lock()
			for _, client := range m.clients {
				client.Conn.Close()
			}
			m.mutex.Unlock()
			return
		}
	}
}

// SendToUser 发送消息给指定用户
func (m *Manager) SendToUser(userID int64, message []byte) error {
	m.mutex.RLock()
	client, exists := m.clients[userID]
	m.mutex.RUnlock()

	if !exists {
		return nil // 用户不在线，忽略消息
	}

	return client.SendMessage(websocket.TextMessage, message)
}

// GetOnlineUsers 获取在线用户ID列表
func (m *Manager) GetOnlineUsers() []int64 {
	m.mutex.RLock()
	defer m.mutex.RUnlock()

	users := make([]int64, 0, len(m.clients))
	for userID := range m.clients {
		users = append(users, userID)
	}
	return users
}

// IsUserOnline 检查用户是否在线
func (m *Manager) IsUserOnline(userID int64) bool {
	m.mutex.RLock()
	defer m.mutex.RUnlock()
	_, exists := m.clients[userID]
	return exists
}

// JoinRoom 加入聊天室
func (m *Manager) JoinRoom(client *Client, roomID int64) {
	m.mutex.Lock()
	defer m.mutex.Unlock()

	// 将房间ID添加到客户端的房间列表
	client.mu.Lock()
	client.Rooms[roomID] = true
	client.mu.Unlock()

	// 将客户端添加到房间的客户端列表
	if _, exists := m.roomMap[roomID]; !exists {
		m.roomMap[roomID] = make(map[*Client]bool)
	}
	m.roomMap[roomID][client] = true
}

// LeaveRoom 离开聊天室
func (m *Manager) LeaveRoom(client *Client, roomID int64) {
	m.mutex.Lock()
	defer m.mutex.Unlock()

	// 从客户端的房间列表中移除
	client.mu.Lock()
	delete(client.Rooms, roomID)
	client.mu.Unlock()

	// 从房间的客户端列表中移除
	if room, exists := m.roomMap[roomID]; exists {
		delete(room, client)
		if len(room) == 0 {
			delete(m.roomMap, roomID)
		}
	}
}

// SendToRoom 发送消息给聊天室
func (m *Manager) SendToRoom(selfUserID int64, roomID int64, message *Message) {
	m.mutex.RLock()
	room, exists := m.roomMap[roomID]
	m.mutex.RUnlock()

	if !exists {
		return
	}

	message.Timestamp = time.Now().Unix()
	data, err := json.Marshal(message)
	if err != nil {
		log.Printf("error marshaling message: %v", err)
		return
	}

	for client := range room {
		if client.UserID != selfUserID {
			if err := client.SendMessage(websocket.TextMessage, data); err != nil {
				log.Printf("error sending message to room member: %v", err)
				continue
			}
		}
	}
}

// Broadcast 广播消息给所有在线用户
func (m *Manager) Broadcast(message *Message) {
	message.Timestamp = time.Now().Unix()
	data, err := json.Marshal(message)
	if err != nil {
		return
	}

	m.broadcast <- data
}

// GetClient 根据用户ID获取客户端
func (m *Manager) GetClient(userID int64) (*Client, bool) {
	m.mutex.RLock()
	defer m.mutex.RUnlock()
	client, exists := m.clients[userID]
	return client, exists
}
