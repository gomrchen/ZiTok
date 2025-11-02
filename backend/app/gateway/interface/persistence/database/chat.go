package database

import (
	"context"
	"database/sql"
	"strings"

	"github.com/pkg/errors"

	"github.com/mutezebra/tiktok/app/gateway/domain/repository"
	"github.com/mutezebra/tiktok/pkg/log"
)

type ChatRepository struct {
	db *sql.DB
}

func NewChatRepository() *ChatRepository { return &ChatRepository{_db} }

func (repo *ChatRepository) WhetherExistUser(ctx context.Context, uid int64) (bool, error) {
	var exist bool
	err := repo.db.QueryRowContext(ctx, "SELECT EXISTS(SELECT 1 FROM user WHERE id=?)", uid).Scan(&exist)
	return exist, err
}

func (repo *ChatRepository) CreateMessage(ctx context.Context, msg *repository.Message) error {
	_, err := repo.db.ExecContext(ctx, "INSERT INTO chat_messages(uid, receiver_id, content, create_at,have_read) VALUES(?,?,?,?,?)", msg.UID, msg.ReceiverID, msg.Content, msg.CreateAt, msg.HaveRead)
	if err != nil {
		return errors.Wrap(err, "failed to create msg item")
	}
	return nil
}

func (repo *ChatRepository) CreateMessageWithChannel(ctx context.Context, msgs chan *repository.Message) {
	stmt, err := repo.db.PrepareContext(ctx, "INSERT INTO chat_messages(uid, receiver_id, content, create_at,have_read) VALUES(?,?,?,?,?)")
	if err != nil {
		log.LogrusObj.Panic(errors.Wrap(err, "prepare query to create msg item failed"))
	}
	defer func() {
		if err = stmt.Close(); err != nil {
			log.LogrusObj.Error(errors.Wrap(err, "failed to close stmt"))
		}
	}()

	for {
		msg, ok := <-msgs
		if !ok {
			break
		}
		if _, err = stmt.ExecContext(ctx, msg.UID, msg.ReceiverID, msg.Content, msg.CreateAt, msg.HaveRead); err != nil {
			log.LogrusObj.Error(errors.Wrap(err, "failed to create msg item"))
			break
		}
	}
}

func (repo *ChatRepository) ChatMessageHistory(ctx context.Context, req *repository.HistoryQueryReq) ([]repository.Message, error) {
	offset := int32(req.PageSize) * (req.PageNum - 1)
	rows, err := repo.db.QueryContext(ctx, "SELECT * FROM chat_messages WHERE ((uid=? AND receiver_id=?) OR (uid=? AND receiver_id=?)) AND delete_at IS NULL AND create_at BETWEEN ? AND ? LIMIT ? OFFSET ?", req.From, req.To, req.To, req.From, req.Start, req.End, req.PageSize, offset)
	if err != nil {
		return nil, errors.Wrap(err, "failed to query chat message history")
	}
	defer func() {
		if err = rows.Close(); err != nil {
			log.LogrusObj.Error(errors.Wrap(err, "failed to close rows"))
		}
	}()

	var msgs []repository.Message
	for rows.Next() {
		var msg repository.Message
		if err = rows.Scan(
			&msg.ID, &msg.UID, &msg.ReceiverID, &msg.Content,
			&msg.CreateAt, &msg.DeleteAt, &msg.HaveRead); err != nil {
			err = errors.Wrap(err, "failed to scan chat message")
			return nil, err
		}
		msgs = append(msgs, msg)
	}
	return msgs, err
}

func (repo *ChatRepository) NotReadMessage(ctx context.Context, uid int64, receiverID int64) ([]repository.Message, error) {
	rows, err := repo.db.QueryContext(ctx, "SELECT * FROM chat_messages WHERE uid=? AND receiver_id=? AND have_read=false AND delete_at IS NULL", uid, receiverID)
	if err != nil {
		return nil, errors.Wrap(err, "failed when find not read messages")
	}
	defer func() {
		if err = rows.Close(); err != nil {
			log.LogrusObj.Error(errors.Wrap(err, "failed to close rows"))
		}
	}()

	var msgs []repository.Message
	for rows.Next() {
		var msg repository.Message
		if err = rows.Scan(
			&msg.ID, &msg.UID, &msg.ReceiverID, &msg.Content,
			&msg.CreateAt, &msg.DeleteAt, &msg.HaveRead); err != nil {
			err = errors.Wrap(err, "failed to scan chat message")
			return nil, err
		}
		msgs = append(msgs, msg)
	}

	if len(msgs) == 0 {
		return msgs, nil
	}

	ids := make([]interface{}, len(msgs))
	for i, msg := range msgs {
		ids[i] = msg.ID
	}

	stmt := `UPDATE chat_messages SET have_read=true WHERE id IN (?` + strings.Repeat(",?", len(ids)-1) + `)`
	_, err = repo.db.ExecContext(ctx, stmt, ids...)
	if err != nil {
		return nil, errors.Wrap(err, "failed to update have_read value")
	}

	return msgs, nil
}
