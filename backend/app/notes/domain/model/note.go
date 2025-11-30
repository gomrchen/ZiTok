package model

import (
	"time"
)

// Note 笔记模型
type Note struct {
	ID            int64      `gorm:"primaryKey" json:"id"`
	UserID        int64      `gorm:"index:idx_user_id" json:"user_id"`
	VideoID       int64      `gorm:"index:idx_video_id" json:"video_id"`
	RelatedUserID int64      `gorm:"index:idx_related_user_id" json:"related_user_id"` // 关联用户ID
	Title         string     `gorm:"size:255" json:"title"`
	Content       string     `gorm:"type:text" json:"content"`
	Seconds       int32      `json:"seconds"`
	Status        int8       `gorm:"default:0" json:"status"` // 0:正常, 1:删除
	CreatedAt     time.Time  `json:"created_at"`
	UpdatedAt     time.Time  `json:"updated_at"`
	DeletedAt     *time.Time `gorm:"index" json:"deleted_at"`
	LikeCount     int32      `json:"like_count" gorm:"-"`     // 点赞数（非数据库字段）
	CommentCount  int32      `json:"comment_count" gorm:"-"`  // 评论数（非数据库字段）
	FavoriteCount int32      `json:"favorite_count" gorm:"-"` // 收藏数（非数据库字段）
}

// TableName 指定表名
func (Note) TableName() string {
	return "notes"
}

// NoteLike 笔记点赞模型
type NoteLike struct {
	ID        int64      `gorm:"primaryKey" json:"id"`
	NoteID    int64      `gorm:"index:idx_note_id;index:idx_user_note,unique" json:"note_id"`
	UserID    int64      `gorm:"index:idx_user_id;index:idx_user_note,unique" json:"user_id"`
	CreatedAt time.Time  `json:"created_at"`
	DeletedAt *time.Time `gorm:"index" json:"deleted_at"`
}

// TableName 指定表名
func (NoteLike) TableName() string {
	return "note_likes"
}

// NoteComment 笔记评论模型
type NoteComment struct {
	ID        int64      `gorm:"primaryKey" json:"id"`
	NoteID    int64      `gorm:"index:idx_note_id" json:"note_id"`
	UserID    int64      `gorm:"index:idx_user_id" json:"user_id"`
	Content   string     `gorm:"type:text" json:"content"`
	ParentID  *int64     `gorm:"index:idx_parent_id" json:"parent_id"`
	CreatedAt time.Time  `json:"created_at"`
	UpdatedAt time.Time  `json:"updated_at"`
	DeletedAt *time.Time `gorm:"index" json:"deleted_at"`
}

// TableName 指定表名
func (NoteComment) TableName() string {
	return "note_comments"
}

// NoteFavorite 笔记收藏模型
type NoteFavorite struct {
	ID        int64      `gorm:"primaryKey" json:"id"`
	NoteID    int64      `gorm:"index:idx_note_id;index:idx_user_note,unique" json:"note_id"`
	UserID    int64      `gorm:"index:idx_user_id;index:idx_user_note,unique" json:"user_id"`
	CreatedAt time.Time  `json:"created_at"`
	DeletedAt *time.Time `gorm:"index" json:"deleted_at"`
}

// TableName 指定表名
func (NoteFavorite) TableName() string {
	return "note_favorites"
}

// NoteStats 笔记统计信息
type NoteStats struct {
	LikeCount     int32 `json:"like_count"`
	CommentCount  int32 `json:"comment_count"`
	FavoriteCount int32 `json:"favorite_count"`
}

// NoteInfo 笔记详情信息
type NoteInfo struct {
	Note
	Author      *UserInfo  `json:"author"`
	Stats       *NoteStats `json:"stats"`
	IsLiked     bool       `json:"is_liked"`
	IsFavorited bool       `json:"is_favorited"`
}

// UserInfo 用户信息
type UserInfo struct {
	ID        int64  `json:"id"`
	Username  string `json:"username"`
	AvatarURL string `json:"avatar_url"`
	Signature string `json:"signature"`
}
