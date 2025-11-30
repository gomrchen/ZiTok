package usecase

import (
	"context"
	"errors"

	"github.com/yxrxy/videoHub/app/social/domain/model"
)

// SendPrivateMessage 私信相关
func (s *useCase) SendPrivateMessage(ctx context.Context, senderID, receiverID int64, content string) error {
	if err := s.svc.SavePrivateMessage(ctx, senderID, receiverID, content); err != nil {
		return err
	}
	return nil
}

// GetPrivateMessages 获取私信列表
func (s *useCase) GetPrivateMessages(ctx context.Context, senderID, receiverID int64, page, size int32) ([]*model.PrivateMessage, error) {
	messages, _, err := s.db.GetPrivateMessages(ctx, senderID, receiverID, int(page), int(size))
	if err != nil {
		return nil, err
	}

	// 转换为domain类型
	domainMessages := make([]*model.PrivateMessage, 0, len(messages))
	for _, msg := range messages {
		domainMsg := &model.PrivateMessage{
			ID:         msg.ID,
			SenderID:   msg.SenderID,
			ReceiverID: msg.ReceiverID,
			Content:    msg.Content,
			IsRead:     msg.IsRead,
		}
		domainMessages = append(domainMessages, domainMsg)
	}

	return domainMessages, nil
}

// CreateChatRoom 聊天室相关
func (s *useCase) CreateChatRoom(ctx context.Context, name string, creatorID int64, roomType int8, memberIDs []int64) (*model.ChatRoom, error) {
	room := &model.ChatRoom{
		Name:      name,
		CreatorID: creatorID,
		Type:      roomType,
	}

	members, err := s.svc.CreateChatRoom(ctx, name, creatorID, memberIDs)
	if err != nil {
		return nil, err
	}

	room.Members = members
	id, err := s.db.CreateChatRoom(ctx, room)
	if err != nil {
		return nil, err
	}
	room.ID = id

	// 转换为domain类型
	domainRoom := &model.ChatRoom{
		ID:        room.ID,
		Name:      room.Name,
		CreatorID: room.CreatorID,
		Type:      room.Type,
	}

	return domainRoom, nil
}

func (s *useCase) GetChatRoom(ctx context.Context, roomID int64) (*model.ChatRoom, error) {
	room, err := s.db.GetChatRoom(ctx, roomID)
	if err != nil {
		return nil, err
	}

	// 转换为domain类型
	domainRoom := &model.ChatRoom{
		ID:        room.ID,
		Name:      room.Name,
		CreatorID: room.CreatorID,
		Type:      room.Type,
	}

	return domainRoom, nil
}

func (s *useCase) GetUserChatRooms(ctx context.Context, userID int64) ([]*model.ChatRoom, error) {
	rooms, err := s.db.GetUserChatRooms(ctx, userID)
	if err != nil {
		return nil, err
	}

	// 转换为domain类型
	domainRooms := make([]*model.ChatRoom, 0, len(rooms))
	for _, room := range rooms {
		domainRoom := &model.ChatRoom{
			ID:        room.ID,
			Name:      room.Name,
			CreatorID: room.CreatorID,
			Type:      room.Type,
		}
		domainRooms = append(domainRooms, domainRoom)
	}

	return domainRooms, nil
}

// 聊天消息相关
func (s *useCase) SendChatMessage(ctx context.Context, roomID, senderID int64, content string, msgType int8) error {
	msg := &model.ChatMessage{
		RoomID:   roomID,
		SenderID: senderID,
		Content:  content,
		Type:     msgType,
	}
	if err := s.db.SendChatMessage(ctx, msg); err != nil {
		return err
	}

	return nil
}

func (s *useCase) GetChatMessages(ctx context.Context, roomID int64, page, size int32) ([]*model.ChatMessage, error) {
	messages, _, err := s.db.GetChatMessages(ctx, roomID, int(page), int(size))
	if err != nil {
		return nil, err
	}

	// 转换为domain类型
	domainMessages := make([]*model.ChatMessage, 0, len(messages))
	for _, msg := range messages {
		domainMsg := &model.ChatMessage{
			ID:       msg.ID,
			RoomID:   msg.RoomID,
			SenderID: msg.SenderID,
			CreateAt: msg.CreateAt,
			Content:  msg.Content,
			Type:     msg.Type,
		}
		domainMessages = append(domainMessages, domainMsg)
	}

	return domainMessages, nil
}

// 好友关系相关
func (s *useCase) AddFriend(ctx context.Context, userID, friendID int64) (*model.Friendship, error) {
	// 检查用户是否存在
	exists, err := s.db.IsUserExists(ctx, userID)
	if err != nil {
		return nil, err
	}
	if !exists {
		return nil, errors.New("user not found")
	}

	exists, err = s.db.IsUserExists(ctx, friendID)
	if err != nil {
		return nil, err
	}
	if !exists {
		return nil, errors.New("friend not found")
	}

	// 检查是否已经是好友
	if friendship, err := s.db.GetFriendship(ctx, userID, friendID); err == nil && friendship != nil {
		return nil, errors.New("已经关注对方，对方回关就是好友啦")
	}

	// 检查对方是否已经关注自己
	reverseFriendship, err := s.db.GetFriendship(ctx, friendID, userID)
	if err == nil && reverseFriendship != nil {
		// 如果对方已经关注自己，将两者的状态都设置为已接受
		if reverseFriendship.Status == model.FriendStatusPending {
			// 创建当前用户关注对方的记录
			friendship := &model.Friendship{
				UserID:   userID,
				FriendID: friendID,
				Status:   model.FriendStatusAccepted,
			}
			if err := s.db.AddFriend(ctx, friendship); err != nil {
				return nil, err
			}

			// 更新对方的关注状态为已接受
			reverseFriendship.Status = model.FriendStatusAccepted
			if err := s.db.UpdateFriendship(ctx, reverseFriendship); err != nil {
				return nil, err
			}

			// 返回新创建的友谊对象
			createdFriendship, err := s.db.GetFriendship(ctx, userID, friendID)
			if err != nil {
				return nil, err
			}
			return createdFriendship, nil
		}
	}

	// 创建关注请求
	friendship := &model.Friendship{
		UserID:   userID,
		FriendID: friendID,
		Status:   model.FriendStatusPending,
	}
	if err := s.db.AddFriend(ctx, friendship); err != nil {
		return nil, err
	}

	// 获取创建的友谊对象
	createdFriendship, err := s.db.GetFriendship(ctx, userID, friendID)
	if err != nil {
		return nil, err
	}

	return createdFriendship, nil
}

func (s *useCase) GetFriendship(ctx context.Context, userID, friendID int64) (*model.Friendship, error) {
	friendship, err := s.db.GetFriendship(ctx, userID, friendID)
	if err != nil {
		return nil, err
	}

	// 只返回状态为已接受的好友关系
	if friendship.Status != model.FriendStatusAccepted {
		return nil, errors.New("好友关系不存在或未确认")
	}

	return friendship, nil
}

func (s *useCase) GetUserFriends(ctx context.Context, userID int64) ([]*model.Friendship, error) {
	friendships, err := s.db.GetUserFriends(ctx, userID)
	if err != nil {
		return nil, err
	}

	// 只返回状态为已接受的好友关系
	domainFriendships := make([]*model.Friendship, 0)
	for _, friendship := range friendships {
		// 只添加状态为已接受的好友关系
		if friendship.Status == model.FriendStatusAccepted {
			domainFriendship := &model.Friendship{
				ID:       friendship.ID,
				UserID:   friendship.UserID,
				FriendID: friendship.FriendID,
				Status:   friendship.Status,
				Remark:   friendship.Remark,
			}
			domainFriendships = append(domainFriendships, domainFriendship)
		}
	}

	return domainFriendships, nil
}

// 好友申请相关 gateway
func (s *useCase) CreateFriendRequest(ctx context.Context, senderID, receiverID int64, message string) error {
	request := &model.FriendRequest{
		SenderID:   senderID,
		ReceiverID: receiverID,
		Message:    message,
		Status:     model.FriendRequestStatusPending,
	}
	if err := s.db.CreateFriendRequest(ctx, request); err != nil {
		return err
	}

	return nil
}

func (s *useCase) GetFriendRequests(ctx context.Context, userID int64, status int8) ([]*model.FriendRequest, error) {
	requests, err := s.db.GetFriendRequests(ctx, userID, status)
	if err != nil {
		return nil, err
	}

	// 转换为domain类型
	domainRequests := make([]*model.FriendRequest, 0, len(requests))
	for _, request := range requests {
		domainRequest := &model.FriendRequest{
			ID:         request.ID,
			ReceiverID: request.ReceiverID,
			SenderID:   request.SenderID,
			Status:     request.Status,
		}
		domainRequests = append(domainRequests, domainRequest)
	}

	return domainRequests, nil
}

func (s *useCase) HandleFriendRequest(ctx context.Context, requestID int64, status int8) error {
	return s.db.UpdateFriendRequest(ctx, requestID, status)
}

// MarkMessageRead 消息已读状态相关
func (s *useCase) MarkMessageRead(ctx context.Context, messageID, userID int64) error {
	return s.db.MarkMessageRead(ctx, messageID, userID)
}

func (s *useCase) GetUnreadMessageCount(ctx context.Context, userID int64) (int64, error) {
	return s.db.GetUnreadMessageCount(ctx, userID)
}
