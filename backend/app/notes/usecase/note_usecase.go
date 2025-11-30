package usecase

import (
	"context"
	"errors"
	"fmt"

	"github.com/yxrxy/videoHub/app/notes/domain/model"
	"github.com/yxrxy/videoHub/app/notes/domain/repository"
	"github.com/yxrxy/videoHub/app/notes/domain/service"
)

// NoteUsecase 笔记用例
type NoteUsecase struct {
	noteService           service.NoteService
	noteRepository        repository.NoteRepository
	noteLikeRepository    repository.NoteLikeRepository
	noteCommentRepository repository.NoteCommentRepository
	noteFavoriteRepository repository.NoteFavoriteRepository
}

// NewNoteUsecase 创建笔记用例实例
func NewNoteUsecase(
	noteService service.NoteService,
	noteRepository repository.NoteRepository,
	noteLikeRepository repository.NoteLikeRepository,
	noteCommentRepository repository.NoteCommentRepository,
	noteFavoriteRepository repository.NoteFavoriteRepository,
) *NoteUsecase {
	return &NoteUsecase{
		noteService:            noteService,
		noteRepository:         noteRepository,
		noteLikeRepository:     noteLikeRepository,
		noteCommentRepository:  noteCommentRepository,
		noteFavoriteRepository: noteFavoriteRepository,
	}
}

// CreateNote 创建笔记
func (u *NoteUsecase) CreateNote(ctx context.Context, req *service.CreateNoteReq) (*model.Note, error) {
	// 参数校验
	if req.UserID <= 0 {
		return nil, errors.New("user id is invalid")
	}
	// VideoID和RelatedUserID至少需要一个有效
	if req.VideoID <= 0 && req.RelatedUserID <= 0 {
		return nil, errors.New("either video id or related user id must be valid")
	}
	if req.Title == "" || req.Content == "" {
		return nil, errors.New("title or content is empty")
	}

	// 创建笔记
	note, err := u.noteService.CreateNote(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("create note failed: %w", err)
	}

	return note, nil
}

// GetVideoNotes 获取视频的笔记列表
func (u *NoteUsecase) GetVideoNotes(ctx context.Context, videoID int64, page, pageSize int) ([]*model.Note, int64, error) {
	if videoID <= 0 {
		return nil, 0, errors.New("video id is invalid")
	}

	// 获取笔记列表
	notes, total, err := u.noteRepository.GetByVideoID(ctx, videoID, page, pageSize)
	if err != nil {
		return nil, 0, fmt.Errorf("get video notes failed: %w", err)
	}

	// 获取笔记统计信息
	if len(notes) > 0 {
		noteIDs := make([]int64, len(notes))
		for i, note := range notes {
			noteIDs[i] = note.ID
		}

		stats, err := u.noteRepository.GetStatsByIDs(ctx, noteIDs)
		if err != nil {
			return nil, 0, fmt.Errorf("get note stats failed: %w", err)
		}

		// 填充统计信息
		for _, note := range notes {
			if s, exists := stats[note.ID]; exists {
				note.LikeCount = s.LikeCount
				note.CommentCount = s.CommentCount
				note.FavoriteCount = s.FavoriteCount
			}
		}
	}

	return notes, total, nil
}

// GetUserNotes 获取用户的笔记列表
func (u *NoteUsecase) GetUserNotes(ctx context.Context, userID int64, page, pageSize int) ([]*model.Note, int64, error) {
	if userID <= 0 {
		return nil, 0, errors.New("user id is invalid")
	}

	// 获取笔记列表
	notes, total, err := u.noteRepository.GetByUserID(ctx, userID, page, pageSize)
	if err != nil {
		return nil, 0, fmt.Errorf("get user notes failed: %w", err)
	}

	// 获取笔记统计信息
	if len(notes) > 0 {
		noteIDs := make([]int64, len(notes))
		for i, note := range notes {
			noteIDs[i] = note.ID
		}

		stats, err := u.noteRepository.GetStatsByIDs(ctx, noteIDs)
		if err != nil {
			return nil, 0, fmt.Errorf("get note stats failed: %w", err)
		}

		// 填充统计信息
		for _, note := range notes {
			if s, exists := stats[note.ID]; exists {
				note.LikeCount = s.LikeCount
				note.CommentCount = s.CommentCount
				note.FavoriteCount = s.FavoriteCount
			}
		}
	}

	return notes, total, nil
}

// DeleteNote 删除笔记
func (u *NoteUsecase) DeleteNote(ctx context.Context, id, userID int64) error {
	if id <= 0 {
		return errors.New("note id is invalid")
	}

	// 检查笔记是否存在
	note, err := u.noteRepository.GetByID(ctx, id)
	if err != nil {
		return fmt.Errorf("get note failed: %w", err)
	}

	if note == nil {
		return errors.New("note not found")
	}

	// 检查权限
	if note.UserID != userID {
		return errors.New("no permission to delete this note")
	}

	// 删除笔记
	err = u.noteRepository.Delete(ctx, id, userID)
	if err != nil {
		return fmt.Errorf("delete note failed: %w", err)
	}

	return nil
}

// LikeNote 点赞笔记
func (u *NoteUsecase) LikeNote(ctx context.Context, noteID, userID int64) error {
	if noteID <= 0 {
		return errors.New("note id is invalid")
	}

	// 检查笔记是否存在
	note, err := u.noteRepository.GetByID(ctx, noteID)
	if err != nil {
		return fmt.Errorf("get note failed: %w", err)
	}

	if note == nil {
		return errors.New("note not found")
	}

	// 使用Like方法点赞
	err = u.noteLikeRepository.Like(ctx, noteID, userID)
	if err != nil {
		return fmt.Errorf("like note failed: %w", err)
	}

	return nil
}

// UnlikeNote 取消点赞
func (u *NoteUsecase) UnlikeNote(ctx context.Context, noteID, userID int64) error {
	if noteID <= 0 {
		return errors.New("note id is invalid")
	}

	// 使用Unlike方法取消点赞
	err := u.noteLikeRepository.Unlike(ctx, noteID, userID)
	if err != nil {
		return fmt.Errorf("unlike note failed: %w", err)
	}

	return nil
}

// FavoriteNote 收藏笔记
func (u *NoteUsecase) FavoriteNote(ctx context.Context, noteID, userID int64) error {
	if noteID <= 0 {
		return errors.New("note id is invalid")
	}

	// 检查笔记是否存在
	note, err := u.noteRepository.GetByID(ctx, noteID)
	if err != nil {
		return fmt.Errorf("get note failed: %w", err)
	}

	if note == nil {
		return errors.New("note not found")
	}

	// 使用Favorite方法收藏
	err = u.noteFavoriteRepository.Favorite(ctx, noteID, userID)
	if err != nil {
		return fmt.Errorf("favorite note failed: %w", err)
	}

	return nil
}

// UnfavoriteNote 取消收藏
func (u *NoteUsecase) UnfavoriteNote(ctx context.Context, noteID, userID int64) error {
	if noteID <= 0 {
		return errors.New("note id is invalid")
	}

	// 使用Unfavorite方法取消收藏
	err := u.noteFavoriteRepository.Unfavorite(ctx, noteID, userID)
	if err != nil {
		return fmt.Errorf("unfavorite note failed: %w", err)
	}

	return nil
}

// GetUserFavoriteNotes 获取用户收藏的笔记列表
func (u *NoteUsecase) GetUserFavoriteNotes(ctx context.Context, userID int64, page, pageSize int) ([]*model.Note, int64, error) {
	if userID <= 0 {
		return nil, 0, errors.New("user id is invalid")
	}

	// 获取收藏的笔记列表
	notes, total, err := u.noteFavoriteRepository.GetUserFavoriteWithNoteInfo(ctx, userID, page, pageSize)
	if err != nil {
		return nil, 0, fmt.Errorf("get user favorite notes failed: %w", err)
	}

	// 获取笔记统计信息
	if len(notes) > 0 {
		noteIDs := make([]int64, len(notes))
		for i, note := range notes {
			noteIDs[i] = note.ID
		}

		stats, err := u.noteRepository.GetStatsByIDs(ctx, noteIDs)
		if err != nil {
			return nil, 0, fmt.Errorf("get note stats failed: %w", err)
		}

		// 填充统计信息
		for _, note := range notes {
			if s, exists := stats[note.ID]; exists {
				note.LikeCount = s.LikeCount
				note.CommentCount = s.CommentCount
				note.FavoriteCount = s.FavoriteCount
			}
		}
	}

	return notes, total, nil
}

// GetNoteDetail 获取笔记详情
func (u *NoteUsecase) GetNoteDetail(ctx context.Context, noteID int64) (*model.Note, error) {
	if noteID <= 0 {
		return nil, errors.New("note id is invalid")
	}

	// 获取笔记详情
	note, err := u.noteRepository.GetByID(ctx, noteID)
	if err != nil {
		return nil, fmt.Errorf("get note failed: %w", err)
	}

	if note == nil {
		return nil, errors.New("note not found")
	}

	// 获取统计信息
	stats, err := u.noteRepository.GetStatsByIDs(ctx, []int64{noteID})
	if err != nil {
		return nil, fmt.Errorf("get note stats failed: %w", err)
	}

	// 填充统计信息
	if s, exists := stats[noteID]; exists {
		note.LikeCount = s.LikeCount
		note.CommentCount = s.CommentCount
		note.FavoriteCount = s.FavoriteCount
	}

	return note, nil
}