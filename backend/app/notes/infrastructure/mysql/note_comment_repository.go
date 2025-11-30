package mysql

import (
	"context"

	"github.com/yxrxy/videoHub/app/notes/domain/model"
	"github.com/yxrxy/videoHub/app/notes/domain/repository"
	"gorm.io/gorm"
)

// NoteCommentRepository MySQL实现的笔记评论仓库
type NoteCommentRepository struct {
	db *gorm.DB
}

// NewNoteCommentRepository 创建笔记评论仓库实例
func NewNoteCommentRepository(db *gorm.DB) repository.NoteCommentRepository {
	return &NoteCommentRepository{db: db}
}

// Create 创建评论
func (r *NoteCommentRepository) Create(ctx context.Context, comment *model.NoteComment) error {
	return r.db.WithContext(ctx).Create(comment).Error
}

// GetByID 根据ID获取评论
func (r *NoteCommentRepository) GetByID(ctx context.Context, id int64) (*model.NoteComment, error) {
	var comment model.NoteComment
	err := r.db.WithContext(ctx).Where("id = ? AND deleted_at IS NULL", id).First(&comment).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, nil
		}
		return nil, err
	}
	return &comment, nil
}

// GetByNoteID 根据笔记ID获取评论列表
func (r *NoteCommentRepository) GetByNoteID(ctx context.Context, noteID int64, page, pageSize int) ([]*model.NoteComment, int64, error) {
	var comments []*model.NoteComment
	var total int64

	offset := (page - 1) * pageSize

	// 获取总数
	err := r.db.WithContext(ctx).Model(&model.NoteComment{}).
		Where("note_id = ? AND deleted_at IS NULL AND parent_id = 0", noteID).
		Count(&total).Error
	if err != nil {
		return nil, 0, err
	}

	// 获取评论列表
	err = r.db.WithContext(ctx).Where("note_id = ? AND deleted_at IS NULL AND parent_id = 0", noteID).
		Order("created_at DESC").
		Offset(offset).Limit(pageSize).
		Find(&comments).Error
	if err != nil {
		return nil, 0, err
	}

	return comments, total, nil
}

// GetByParentID 获取子评论
func (r *NoteCommentRepository) GetByParentID(ctx context.Context, parentID int64, page, pageSize int) ([]*model.NoteComment, int64, error) {
	var comments []*model.NoteComment
	var total int64

	offset := (page - 1) * pageSize

	// 获取总数
	err := r.db.WithContext(ctx).Model(&model.NoteComment{}).
		Where("parent_id = ? AND deleted_at IS NULL", parentID).
		Count(&total).Error
	if err != nil {
		return nil, 0, err
	}

	// 获取子评论列表
	err = r.db.WithContext(ctx).Where("parent_id = ? AND deleted_at IS NULL", parentID).
		Order("created_at ASC").
		Offset(offset).Limit(pageSize).
		Find(&comments).Error
	if err != nil {
		return nil, 0, err
	}

	return comments, total, nil
}

// Delete 删除评论
func (r *NoteCommentRepository) Delete(ctx context.Context, id, userID int64) error {
	// 检查评论是否存在且属于该用户
	var comment model.NoteComment
	err := r.db.WithContext(ctx).Where("id = ? AND user_id = ? AND deleted_at IS NULL", id, userID).First(&comment).Error
	if err != nil {
		return err
	}

	// 软删除评论
	return r.db.WithContext(ctx).Model(&comment).Update("deleted_at", gorm.Expr("NOW()")).Error
}

// GetByUserID 获取用户的评论列表
func (r *NoteCommentRepository) GetByUserID(ctx context.Context, userID int64, page, pageSize int) ([]*model.NoteComment, int64, error) {
	var comments []*model.NoteComment
	var total int64

	offset := (page - 1) * pageSize

	// 获取总数
	err := r.db.WithContext(ctx).Model(&model.NoteComment{}).
		Where("user_id = ? AND deleted_at IS NULL", userID).
		Count(&total).Error
	if err != nil {
		return nil, 0, err
	}

	// 获取评论列表
	err = r.db.WithContext(ctx).Where("user_id = ? AND deleted_at IS NULL", userID).
		Order("created_at DESC").
		Offset(offset).Limit(pageSize).
		Find(&comments).Error
	if err != nil {
		return nil, 0, err
	}

	return comments, total, nil
}

// GetCommentCount 获取笔记的评论数
func (r *NoteCommentRepository) GetCommentCount(ctx context.Context, noteID int64) (int32, error) {
	var count int64
	err := r.db.WithContext(ctx).Model(&model.NoteComment{}).
		Where("note_id = ? AND deleted_at IS NULL", noteID).
		Count(&count).Error
	if err != nil {
		return 0, err
	}
	return int32(count), nil
}
