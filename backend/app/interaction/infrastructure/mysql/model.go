package mysql

import "time"

// Like 点赞模型
type Like struct {
	ID        int64  `gorm:"primarykey;column:id;comment:点赞ID"`
	UserID    int64  `gorm:"index:idx_user_video;not null;column:user_id;comment:用户ID"`
	VideoID   int64  `gorm:"index:idx_user_video;not null;column:video_id;comment:视频ID"`
	DeletedAt *int64 `gorm:"column:deleted_at;comment:删除时间"`
}

// TableName 指定表名
func (Like) TableName() string {
	return "likes"
}

// Comment 评论模型
type Comment struct {
	ID        int64  `gorm:"primarykey;column:id;comment:评论ID"`
	UserID    int64  `gorm:"index:idx_video;not null;column:user_id;comment:用户ID"`
	VideoID   int64  `gorm:"index:idx_video;not null;column:video_id;comment:视频ID"`
	Content   string `gorm:"type:text;not null;column:content;comment:评论内容"`
	ParentID  *int64 `gorm:"column:parent_id;comment:父评论ID"`
	LikeCount int32  `gorm:"default:0;column:like_count;comment:点赞数"`
	DeletedAt *int64 `gorm:"column:deleted_at;comment:删除时间"`
}

// TableName 指定表名
func (Comment) TableName() string {
	return "comments"
}

// CommentLike 评论点赞模型
type CommentLike struct {
	UserID    int64 `gorm:"index:idx_user_comment;not null;comment:用户ID"`
	CommentID int64 `gorm:"index:idx_user_comment;not null;comment:评论ID"`
}

// TableName 指定表名
func (CommentLike) TableName() string {
	return "comment_likes"
}

// Video 视频模型
type Video struct {
	ID           int64      `json:"id"            gorm:"primarykey"`             // 视频ID
	UserID       int64      `json:"user_id"       gorm:"index"`                  // 作者ID
	VideoURL     string     `json:"video_url"     gorm:"type:varchar(255)"`      // 视频URL
	CoverURL     string     `json:"cover_url"     gorm:"type:varchar(255)"`      // 封面URL
	Title        string     `json:"title"         gorm:"type:varchar(128)"`      // 视频标题
	Description  string     `json:"description"   gorm:"type:varchar(512)"`      // 视频描述
	Duration     int64      `json:"duration"`                                    // 视频时长（秒）
	Category     string     `json:"category"      gorm:"type:varchar(32);index"` // 视频分类
	Tags         string     `json:"tags"          gorm:"type:varchar(255)"`      // 视频标签，以逗号分隔
	VisitCount   int64      `json:"visit_count"   gorm:"default:0"`              // 播放量
	LikeCount    int64      `json:"like_count"    gorm:"default:0"`              // 点赞数
	CommentCount int64      `json:"comment_count" gorm:"default:0"`              // 评论数
	IsPrivate    bool       `json:"is_private"    gorm:"default:false"`          // 是否私有
	CreatedAt    time.Time  `json:"created_at"`                                  // 创建时间
	UpdatedAt    time.Time  `json:"updated_at"`                                  // 更新时间
	DeletedAt    *time.Time `json:"deleted_at"    gorm:"index"`                  // 删除时间
}

// TableName 指定表名
func (Video) TableName() string {
	return "video"
}
