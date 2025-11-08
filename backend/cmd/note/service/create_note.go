package service

import (
	"github.com/ozline/tiktok/cmd/note/dal/db"
	"github.com/ozline/tiktok/kitex_gen/note"
	"github.com/ozline/tiktok/pkg/errno"
	"github.com/ozline/tiktok/pkg/utils"
)

func (s *NoteService) CreateNote(req *note.CreateNoteRequest) (*db.Note, error) {
	claim, err := utils.CheckToken(req.Token)
	if err != nil {
		return nil, errno.AuthorizationFailedError
	}

	// 验证类型
	if req.Type != 1 && req.Type != 2 {
		return nil, errno.ParamError
	}

	// 如果是附件笔记，需要验证是否为视频发布者
	if req.Type == 1 {
		videoOwnerID, err := db.GetVideoOwnerID(s.ctx, req.VideoId)
		if err != nil {
			return nil, errno.VideoNotFoundError
		}
		if videoOwnerID != claim.UserId {
			return nil, errno.AuthorizationFailedError
		}
	}

	noteModel := &db.Note{
		VideoID: req.VideoId,
		UserID:  claim.UserId,
		Content: req.Content,
		Type:    req.Type,
	}

	return db.CreateNote(s.ctx, noteModel)
}

