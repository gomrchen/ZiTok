package service

import (
	"github.com/ozline/tiktok/cmd/note/dal/db"
	"github.com/ozline/tiktok/kitex_gen/note"
	"github.com/ozline/tiktok/pkg/errno"
	"github.com/ozline/tiktok/pkg/utils"
)

func (s *NoteService) DeleteNote(req *note.DeleteNoteRequest) error {
	claim, err := utils.CheckToken(req.Token)
	if err != nil {
		return errno.AuthorizationFailedError
	}

	// 获取笔记信息
	note, err := db.GetNoteByID(s.ctx, req.NoteId)
	if err != nil {
		return errno.NoteNotFoundError
	}

	// 如果是附件笔记，只有视频发布者能删除
	if note.Type == 1 {
		videoOwnerID, err := db.GetVideoOwnerID(s.ctx, note.VideoID)
		if err != nil {
			return errno.VideoNotFoundError
		}
		if videoOwnerID != claim.UserId {
			return errno.AuthorizationFailedError
		}
	} else {
		// 用户笔记，只有创建者能删除
		if note.UserID != claim.UserId {
			return errno.AuthorizationFailedError
		}
	}

	return db.DeleteNote(s.ctx, req.NoteId)
}

