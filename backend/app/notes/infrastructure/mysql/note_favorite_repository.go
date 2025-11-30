package mysql

import (
	"context"
	"time"

	"github.com/yxrxy/videoHub/app/notes/domain/model"
	"github.com/yxrxy/videoHub/app/notes/domain/repository"
	"gorm.io/gorm"
)

// NoteFavoriteRepository MySQL实现的笔记收藏仓库
type NoteFavoriteRepository struct {
	db *gorm.DB
}

// NewNoteFavoriteRepository 创建笔记收藏仓库实例
func NewNoteFavoriteRepository(db *gorm.DB) repository.NoteFavoriteRepository {
	return &NoteFavoriteRepository{db: db}
}

// Create 创建收藏记录
func (r *NoteFavoriteRepository) Create(ctx context.Context, favorite *model.NoteFavorite) error {
	// 先检查是否已收藏
	exists, err := r.Exists(ctx, favorite.UserID, favorite.NoteID)
	if err != nil {
		return err
	}
	if exists {
		// 如果已收藏，取消删除标记
		return r.db.WithContext(ctx).Model(&model.NoteFavorite{}).
			Where("user_id = ? AND note_id = ?", favorite.UserID, favorite.NoteID).
			Update("deleted_at", nil).Error
	}
	return r.db.WithContext(ctx).Create(favorite).Error
}

// Delete 删除收藏记录
func (r *NoteFavoriteRepository) Delete(ctx context.Context, userID, noteID int64) error {
	return r.db.WithContext(ctx).Model(&model.NoteFavorite{}).
		Where("user_id = ? AND note_id = ?", userID, noteID).
		Update("deleted_at", time.Now()).Error
}

// Exists 检查是否已收藏
func (r *NoteFavoriteRepository) Exists(ctx context.Context, userID, noteID int64) (bool, error) {
	var count int64
	err := r.db.WithContext(ctx).Model(&model.NoteFavorite{}).
		Where("user_id = ? AND note_id = ? AND deleted_at IS NULL", userID, noteID).
		Count(&count).Error
	return count > 0, err
}

// GetUserFavorites 获取用户收藏的笔记ID列表
func (r *NoteFavoriteRepository) GetUserFavorites(ctx context.Context, userID int64, page, pageSize int) ([]int64, int64, error) {
	var noteIDs []int64
	var total int64

	offset := (page - 1) * pageSize

	// 获取总数
	err := r.db.WithContext(ctx).Model(&model.NoteFavorite{}).
		Where("user_id = ? AND deleted_at IS NULL", userID).
		Count(&total).Error
	if err != nil {
		return nil, 0, err
	}

	// 获取笔记ID列表
	err = r.db.WithContext(ctx).Model(&model.NoteFavorite{}).
		Select("note_id").
		Where("user_id = ? AND deleted_at IS NULL", userID).
		Order("created_at DESC").
		Offset(offset).Limit(pageSize).
		Pluck("note_id", &noteIDs).Error

	return noteIDs, total, err
}

// GetUserFavoriteWithNoteInfo 获取用户收藏的笔记详情列表
func (r *NoteFavoriteRepository) GetUserFavoriteWithNoteInfo(ctx context.Context, userID int64, page, pageSize int) ([]*model.Note, int64, error) {
	var notes []*model.Note
	var total int64

	offset := (page - 1) * pageSize

	// 获取总数
	err := r.db.WithContext(ctx).Model(&model.NoteFavorite{}).
		Joins("JOIN notes ON notes.id = note_favorites.note_id AND notes.status = 0").
		Where("note_favorites.user_id = ? AND note_favorites.deleted_at IS NULL", userID).
		Count(&total).Error
	if err != nil {
		return nil, 0, err
	}

	// 获取笔记详情列表
	err = r.db.WithContext(ctx).Table("notes").
		Joins("JOIN note_favorites ON notes.id = note_favorites.note_id").
		Where("note_favorites.user_id = ? AND note_favorites.deleted_at IS NULL AND notes.status = 0", userID).
		Order("note_favorites.created_at DESC").
		Offset(offset).Limit(pageSize).
		Find(&notes).Error

	return notes, total, nil
}

// BatchIsFavorited 批量检查点赞状态
func (r *NoteFavoriteRepository) BatchIsFavorited(ctx context.Context, noteIDs []int64, userID int64) (map[int64]bool, error) {
	result := make(map[int64]bool)
	// 初始化所有笔记ID为未收藏
	for _, noteID := range noteIDs {
		result[noteID] = false
	}
	
	// 查询已收藏的笔记ID
	var favorites []*model.NoteFavorite
	err := r.db.WithContext(ctx).
		Where("user_id = ? AND note_id IN ? AND deleted_at IS NULL", userID, noteIDs).
		Find(&favorites).Error
	if err != nil {
		return nil, err
	}
	
	// 更新已收藏的笔记ID状态
	for _, fav := range favorites {
		result[fav.NoteID] = true
	}
	
	return result, nil
}

// Favorite 收藏笔记（接口方法实现）
func (r *NoteFavoriteRepository) Favorite(ctx context.Context, noteID, userID int64) error {
	favorite := &model.NoteFavorite{
		UserID:  userID,
		NoteID:  noteID,
	}
	return r.Create(ctx, favorite)
}

// Unfavorite 取消收藏（接口方法实现）
func (r *NoteFavoriteRepository) Unfavorite(ctx context.Context, noteID, userID int64) error {
	return r.Delete(ctx, userID, noteID)
}

// IsFavorited 检查是否已收藏（接口方法实现）
func (r *NoteFavoriteRepository) IsFavorited(ctx context.Context, noteID, userID int64) (bool, error) {
	return r.Exists(ctx, userID, noteID)
}

// GetFavoriteCount 获取笔记的收藏数
func (r *NoteFavoriteRepository) GetFavoriteCount(ctx context.Context, noteID int64) (int32, error) {
	var count int64
	err := r.db.WithContext(ctx).Model(&model.NoteFavorite{}).
		Where("note_id = ? AND deleted_at IS NULL", noteID).
		Count(&count).Error
	if err != nil {
		return 0, err
	}
	return int32(count), nil
}
