package mysql

import (
	"context"
	"time"

	"github.com/yxrxy/videoHub/app/notes/domain/model"
	"github.com/yxrxy/videoHub/app/notes/domain/repository"
	"gorm.io/gorm"
)

// NoteLikeRepository MySQL实现的笔记点赞仓库
type NoteLikeRepository struct {
	db *gorm.DB
}

// NewNoteLikeRepository 创建笔记点赞仓库实例
func NewNoteLikeRepository(db *gorm.DB) repository.NoteLikeRepository {
	return &NoteLikeRepository{db: db}
}

// Create 创建点赞记录
func (r *NoteLikeRepository) Create(ctx context.Context, like *model.NoteLike) error {
	// 先检查是否已点赞
	exists, err := r.Exists(ctx, like.UserID, like.NoteID)
	if err != nil {
		return err
	}
	if exists {
		// 如果已点赞，取消删除标记
		return r.db.WithContext(ctx).Model(&model.NoteLike{}).
			Where("user_id = ? AND note_id = ?", like.UserID, like.NoteID).
			Update("deleted_at", nil).Error
	}
	return r.db.WithContext(ctx).Create(like).Error
}

// Delete 删除点赞记录
func (r *NoteLikeRepository) Delete(ctx context.Context, userID, noteID int64) error {
	return r.db.WithContext(ctx).Model(&model.NoteLike{}).
		Where("user_id = ? AND note_id = ?", userID, noteID).
		Update("deleted_at", time.Now()).Error
}

// Exists 检查是否已点赞
func (r *NoteLikeRepository) Exists(ctx context.Context, userID, noteID int64) (bool, error) {
	var count int64
	err := r.db.WithContext(ctx).Model(&model.NoteLike{}).
		Where("user_id = ? AND note_id = ? AND deleted_at IS NULL", userID, noteID).
		Count(&count).Error
	return count > 0, err
}

// GetUserLikes 获取用户点赞的笔记ID列表
func (r *NoteLikeRepository) GetUserLikes(ctx context.Context, userID int64, page, pageSize int) ([]int64, int64, error) {
	var noteIDs []int64
	var total int64

	offset := (page - 1) * pageSize

	// 获取总数
	err := r.db.WithContext(ctx).Model(&model.NoteLike{}).
		Where("user_id = ? AND deleted_at IS NULL", userID).
		Count(&total).Error
	if err != nil {
		return nil, 0, err
	}

	// 获取笔记ID列表
	err = r.db.WithContext(ctx).Model(&model.NoteLike{}).
		Select("note_id").
		Where("user_id = ? AND deleted_at IS NULL", userID).
		Order("created_at DESC").
		Offset(offset).Limit(pageSize).
		Pluck("note_id", &noteIDs).Error

	return noteIDs, total, nil
}

// BatchIsLiked 批量检查点赞状态
func (r *NoteLikeRepository) BatchIsLiked(ctx context.Context, noteIDs []int64, userID int64) (map[int64]bool, error) {
	result := make(map[int64]bool)
	// 初始化所有笔记ID为未点赞
	for _, noteID := range noteIDs {
		result[noteID] = false
	}
	
	// 查询已点赞的笔记ID
	var likes []*model.NoteLike
	err := r.db.WithContext(ctx).
		Where("user_id = ? AND note_id IN ? AND deleted_at IS NULL", userID, noteIDs).
		Find(&likes).Error
	if err != nil {
		return nil, err
	}
	
	// 更新已点赞的笔记ID状态
	for _, like := range likes {
		result[like.NoteID] = true
	}
	
	return result, nil
}

// Like 点赞笔记（接口方法实现）
func (r *NoteLikeRepository) Like(ctx context.Context, noteID, userID int64) error {
	like := &model.NoteLike{
		UserID:  userID,
		NoteID:  noteID,
	}
	return r.Create(ctx, like)
}

// Unlike 取消点赞（接口方法实现）
func (r *NoteLikeRepository) Unlike(ctx context.Context, noteID, userID int64) error {
	return r.Delete(ctx, userID, noteID)
}

// IsLiked 检查是否已点赞（接口方法实现）
func (r *NoteLikeRepository) IsLiked(ctx context.Context, noteID, userID int64) (bool, error) {
	return r.Exists(ctx, userID, noteID)
}

// GetLikeCount 获取笔记的点赞数
func (r *NoteLikeRepository) GetLikeCount(ctx context.Context, noteID int64) (int32, error) {
	var count int64
	err := r.db.WithContext(ctx).Model(&model.NoteLike{}).
		Where("note_id = ? AND deleted_at IS NULL", noteID).
		Count(&count).Error
	if err != nil {
		return 0, err
	}
	return int32(count), nil
}
