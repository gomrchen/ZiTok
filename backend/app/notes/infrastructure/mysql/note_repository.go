package mysql

import (
	"context"
	"fmt"

	"github.com/yxrxy/videoHub/app/notes/domain/model"
	"github.com/yxrxy/videoHub/app/notes/domain/repository"
	"gorm.io/gorm"
)

// NoteRepository MySQL实现的笔记仓库
type NoteRepository struct {
	db *gorm.DB
}

// NewNoteRepository 创建笔记仓库实例
func NewNoteRepository(db *gorm.DB) repository.NoteRepository {
	return &NoteRepository{db: db}
}

// Create 创建笔记
func (r *NoteRepository) Create(ctx context.Context, note *model.Note) error {
	return r.db.WithContext(ctx).Create(note).Error
}

// GetByID 根据ID获取笔记
func (r *NoteRepository) GetByID(ctx context.Context, id int64) (*model.Note, error) {
	var note model.Note
	err := r.db.WithContext(ctx).Where("id = ? AND status = 0", id).First(&note).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, nil
		}
		return nil, err
	}
	return &note, nil
}

// GetByVideoID 根据视频ID获取笔记列表
func (r *NoteRepository) GetByVideoID(ctx context.Context, videoID int64, page, pageSize int) ([]*model.Note, int64, error) {
	var notes []*model.Note
	var total int64

	offset := (page - 1) * pageSize

	// 获取总数
	err := r.db.WithContext(ctx).Model(&model.Note{}).Where("video_id = ? AND status = 0", videoID).Count(&total).Error
	if err != nil {
		return nil, 0, err
	}

	// 获取列表
	err = r.db.WithContext(ctx).Where("video_id = ? AND status = 0", videoID).
		Order("created_at DESC").
		Offset(offset).Limit(pageSize).
		Find(&notes).Error
	if err != nil {
		return nil, 0, err
	}

	return notes, total, nil
}

// GetByUserID 根据用户ID获取笔记列表
func (r *NoteRepository) GetByUserID(ctx context.Context, userID int64, page, pageSize int) ([]*model.Note, int64, error) {
	var notes []*model.Note
	var total int64

	offset := (page - 1) * pageSize

	// 获取总数
	err := r.db.WithContext(ctx).Model(&model.Note{}).Where("user_id = ? AND status = 0", userID).Count(&total).Error
	if err != nil {
		return nil, 0, err
	}

	// 获取列表
	err = r.db.WithContext(ctx).Where("user_id = ? AND status = 0", userID).
		Order("created_at DESC").
		Offset(offset).Limit(pageSize).
		Find(&notes).Error
	if err != nil {
		return nil, 0, err
	}

	return notes, total, nil
}

// Delete 删除笔记（软删除）
func (r *NoteRepository) Delete(ctx context.Context, id, userID int64) error {
	result := r.db.WithContext(ctx).Model(&model.Note{}).
		Where("id = ? AND user_id = ? AND status = 0", id, userID).
		Update("status", 1)
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return fmt.Errorf("note not found or no permission")
	}
	return nil
}

// GetByIDs 批量获取笔记
func (r *NoteRepository) GetByIDs(ctx context.Context, ids []int64) ([]*model.Note, error) {
	var notes []*model.Note
	if len(ids) == 0 {
		return notes, nil
	}

	err := r.db.WithContext(ctx).Where("id IN ? AND status = 0", ids).Find(&notes).Error
	return notes, err
}

// GetStatsByIDs 批量获取笔记统计信息
func (r *NoteRepository) GetStatsByIDs(ctx context.Context, ids []int64) (map[int64]*model.NoteStats, error) {
	if len(ids) == 0 {
		return make(map[int64]*model.NoteStats), nil
	}

	// 初始化结果
	result := make(map[int64]*model.NoteStats)
	for _, id := range ids {
		result[id] = &model.NoteStats{}
	}

	// 获取点赞数
	type LikeCount struct {
		NoteID    int64 `gorm:"column:note_id"`
		LikeCount int32 `gorm:"column:like_count"`
	}
	var likeCounts []LikeCount
	err := r.db.WithContext(ctx).Model(&model.NoteLike{}).
		Select("note_id, COUNT(*) as like_count").
		Where("deleted_at IS NULL AND note_id IN (?)", ids).
		Group("note_id").
		Scan(&likeCounts).Error
	if err != nil {
		return nil, err
	}
	for _, lc := range likeCounts {
		if stats, exists := result[lc.NoteID]; exists {
			stats.LikeCount = lc.LikeCount
		}
	}

	// 获取评论数
	type CommentCount struct {
		NoteID       int64 `gorm:"column:note_id"`
		CommentCount int32 `gorm:"column:comment_count"`
	}
	var commentCounts []CommentCount
	err = r.db.WithContext(ctx).Model(&model.NoteComment{}).
		Select("note_id, COUNT(*) as comment_count").
		Where("deleted_at IS NULL AND note_id IN (?)", ids).
		Group("note_id").
		Scan(&commentCounts).Error
	if err != nil {
		return nil, err
	}
	for _, cc := range commentCounts {
		if stats, exists := result[cc.NoteID]; exists {
			stats.CommentCount = cc.CommentCount
		}
	}

	// 获取收藏数
	type FavoriteCount struct {
		NoteID        int64 `gorm:"column:note_id"`
		FavoriteCount int32 `gorm:"column:favorite_count"`
	}
	var favoriteCounts []FavoriteCount
	err = r.db.WithContext(ctx).Model(&model.NoteFavorite{}).
		Select("note_id, COUNT(*) as favorite_count").
		Where("deleted_at IS NULL AND note_id IN (?)", ids).
		Group("note_id").
		Scan(&favoriteCounts).Error
	if err != nil {
		return nil, err
	}
	for _, fc := range favoriteCounts {
		if stats, exists := result[fc.NoteID]; exists {
			stats.FavoriteCount = fc.FavoriteCount
		}
	}

	return result, nil
}
