package db

import (
	"context"
	"time"

	"gorm.io/gorm"
)

type Note struct {
	Id        int64  `json:"id"`
	VideoID   int64  `json:"video_id"`
	UserID    int64  `json:"user_id"`
	Content   string `json:"content" gorm:"type:text"`
	Type      int64  `json:"type"` // 1: 附件笔记(attachment), 2: 用户笔记(user)
	CreatedAt time.Time
	UpdatedAt time.Time
	DeletedAt gorm.DeletedAt `gorm:"index"`
}

func CreateNote(ctx context.Context, note *Note) (*Note, error) {
	note.Id = SF.NextVal()
	if err := DB.WithContext(ctx).Create(note).Error; err != nil {
		return nil, err
	}
	return note, nil
}

func GetNoteByID(ctx context.Context, noteId int64) (*Note, error) {
	var note Note
	if err := DB.WithContext(ctx).Where("id = ?", noteId).First(&note).Error; err != nil {
		return nil, err
	}
	return &note, nil
}

func GetNotesByVideoID(ctx context.Context, videoId int64) ([]Note, error) {
	var notes []Note
	if err := DB.WithContext(ctx).Where("video_id = ?", videoId).Order("created_at DESC").Find(&notes).Error; err != nil {
		return nil, err
	}
	return notes, nil
}

func GetNotesByUserID(ctx context.Context, userId int64) ([]Note, error) {
	var notes []Note
	if err := DB.WithContext(ctx).Where("user_id = ?", userId).Order("created_at DESC").Find(&notes).Error; err != nil {
		return nil, err
	}
	return notes, nil
}

func UpdateNote(ctx context.Context, noteId int64, content string) error {
	return DB.WithContext(ctx).Model(&Note{}).Where("id = ?", noteId).Update("content", content).Error
}

func DeleteNote(ctx context.Context, noteId int64) error {
	return DB.WithContext(ctx).Where("id = ?", noteId).Delete(&Note{}).Error
}

func GetVideoOwnerID(ctx context.Context, videoId int64) (int64, error) {
	var video struct {
		UserID int64
	}
	// 使用原始DB连接查询video表
	if err := BaseDB.WithContext(ctx).Table("video").Select("user_id").Where("id = ?", videoId).First(&video).Error; err != nil {
		return 0, err
	}
	return video.UserID, nil
}

