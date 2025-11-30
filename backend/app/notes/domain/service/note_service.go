package service

import (
	"context"

	"github.com/yxrxy/videoHub/app/notes/domain/model"
	"github.com/yxrxy/videoHub/app/notes/domain/repository"
)

// CreateNoteReq 创建笔记请求
type CreateNoteReq struct {
	UserID        int64  `json:"user_id"`
	VideoID       int64  `json:"video_id"`
	RelatedUserID int64  `json:"related_user_id"` // 关联用户ID
	Title         string `json:"title"`
	Content       string `json:"content"`
	Seconds       int32  `json:"seconds"` // 视频时间戳
}

// NoteService 笔记服务接口
type NoteService interface {
	CreateNote(ctx context.Context, req *CreateNoteReq) (*model.Note, error)
}

// noteServiceImpl 笔记服务实现
type noteServiceImpl struct {
	noteRepository repository.NoteRepository
}

// NewNoteService 创建笔记服务实例
func NewNoteService(noteRepository repository.NoteRepository) NoteService {
	return &noteServiceImpl{
		noteRepository: noteRepository,
	}
}

// CreateNote 创建笔记
func (s *noteServiceImpl) CreateNote(ctx context.Context, req *CreateNoteReq) (*model.Note, error) {
	// 创建笔记模型
	note := &model.Note{
		UserID:        req.UserID,
		VideoID:       req.VideoID,
		RelatedUserID: req.RelatedUserID,
		Title:         req.Title,
		Content:       req.Content,
		Seconds:       req.Seconds,
	}

	// 保存到数据库
	err := s.noteRepository.Create(ctx, note)
	if err != nil {
		return nil, err
	}

	return note, nil
}
