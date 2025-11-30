package mysql

import (
	"time"
    "gorm.io/gorm" // 需要引用 gorm，如果使用了 gorm.DeletedAt
)

type User struct {
	ID            int64      `json:"id"             gorm:"primarykey"`
	Username      string     `json:"username"       gorm:"type:varchar(32);uniqueIndex;not null"`
	Password      string     `json:"-"              gorm:"type:varchar(128);not null"`
	Email         string     `json:"email"          gorm:"type:varchar(128);default:'';index"` // 新增
	AvatarURL     string     `json:"avatar_url"     gorm:"type:varchar(255);default:''"`
	BackgroundURL string     `json:"background_url" gorm:"type:varchar(255);default:''"`       // 新增
	Signature     string     `json:"signature"      gorm:"type:varchar(255);default:''"`       // 新增
	Gender        int8       `json:"gender"         gorm:"type:tinyint(1);default:0"`          // 新增：0:未知 1:男 2:女
	Birthday      *time.Time `json:"birthday"       gorm:"type:date"`                          // 新增：使用指针允许为NULL
	Status        int8       `json:"status"         gorm:"type:tinyint(1);default:0"`          // 新增：0:离线 1:在线
	CreatedAt     time.Time  `json:"created_at"     gorm:"autoCreateTime"`
	UpdatedAt     time.Time  `json:"updated_at"     gorm:"autoUpdateTime"`
	DeletedAt     gorm.DeletedAt `json:"deleted_at,omitempty" gorm:"index"` // 推荐使用 gorm.DeletedAt
}

func (User) TableName() string {
	return "users"
}

// 收藏视频模型
type Favorite struct {
	ID        int64          `json:"id"         gorm:"primarykey"`
	UserID    int64          `json:"user_id"    gorm:"not null;index"`
	VideoID   int64          `json:"video_id"   gorm:"not null;index"`
	CreatedAt time.Time      `json:"created_at" gorm:"autoCreateTime"`
	DeletedAt gorm.DeletedAt `json:"deleted_at,omitempty" gorm:"index"`
}

func (Favorite) TableName() string {
	return "favorites"
}