package drama

import "time"

type Drama struct {
	ID               int64      `gorm:"column:id;primaryKey" json:"id"`
	Title            string     `gorm:"column:title" json:"title"`
	CoverURL         string     `gorm:"column:cover_url" json:"cover_url"`
	Description      string     `gorm:"column:description" json:"description"`
	Category         string     `gorm:"column:category" json:"category"`
	Tags             string     `gorm:"column:tags" json:"tags"`
	TotalEpisodes    int        `gorm:"column:total_episodes" json:"total_episodes"`
	FreeEpisodeCount int        `gorm:"column:free_episode_count" json:"free_episode_count"`
	BundlePrice      int        `gorm:"column:bundle_price" json:"bundle_price"`
	Status           int8       `gorm:"column:status" json:"status"`
	PlayCount        int64      `gorm:"column:play_count" json:"play_count"`
	LikeCount        int64      `gorm:"column:like_count" json:"like_count"`
	CreatedAt        time.Time  `gorm:"column:created_at" json:"created_at"`
	UpdatedAt        time.Time  `gorm:"column:updated_at" json:"updated_at"`
	DeletedAt        *time.Time `gorm:"column:deleted_at" json:"-"`
}

func (Drama) TableName() string { return "drama" }

type Episode struct {
	ID          int64      `gorm:"column:id;primaryKey" json:"id"`
	DramaID     int64      `gorm:"column:drama_id" json:"drama_id"`
	EpisodeNo   int        `gorm:"column:episode_no" json:"episode_no"`
	Title       string     `gorm:"column:title" json:"title"`
	VideoURL    string     `gorm:"column:video_url" json:"video_url"`
	CoverURL    string     `gorm:"column:cover_url" json:"cover_url"`
	Duration    int64      `gorm:"column:duration" json:"duration"`
	IsFree      bool       `gorm:"column:is_free" json:"is_free"`
	UnlockPrice int        `gorm:"column:unlock_price" json:"unlock_price"`
	VisitCount  int64      `gorm:"column:visit_count" json:"visit_count"`
	LikeCount   int64      `gorm:"column:like_count" json:"like_count"`
	CreatedAt   time.Time  `gorm:"column:created_at" json:"created_at"`
	UpdatedAt   time.Time  `gorm:"column:updated_at" json:"updated_at"`
	DeletedAt   *time.Time `gorm:"column:deleted_at" json:"-"`
}

func (Episode) TableName() string { return "episode" }

type WatchProgress struct {
	ID          int64     `gorm:"column:id;primaryKey" json:"id"`
	UserID      int64     `gorm:"column:user_id" json:"user_id"`
	DramaID     int64     `gorm:"column:drama_id" json:"drama_id"`
	EpisodeID   int64     `gorm:"column:episode_id" json:"episode_id"`
	EpisodeNo   int       `gorm:"column:episode_no" json:"episode_no"`
	PositionSec int       `gorm:"column:position_sec" json:"position_sec"`
	UpdatedAt   time.Time `gorm:"column:updated_at" json:"updated_at"`
}

func (WatchProgress) TableName() string { return "user_watch_progress" }

type DramaFavorite struct {
	ID        int64     `gorm:"column:id;primaryKey" json:"id"`
	UserID    int64     `gorm:"column:user_id" json:"user_id"`
	DramaID   int64     `gorm:"column:drama_id" json:"drama_id"`
	CreatedAt time.Time `gorm:"column:created_at" json:"created_at"`
}

func (DramaFavorite) TableName() string { return "user_drama_favorite" }

type FeedItem struct {
	Drama   Drama   `json:"drama"`
	Episode Episode `json:"episode"`
	Locked  bool    `json:"locked"`
}

type PlayInfo struct {
	Episode    Episode `json:"episode"`
	Drama      Drama   `json:"drama"`
	Locked     bool    `json:"locked"`
	UnlockPrice int    `json:"unlock_price"`
	CanPlay    bool    `json:"can_play"`
	VideoURL   string  `json:"video_url"`
}
