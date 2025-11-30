package repository

import (
	"context"

	"github.com/yxrxy/videoHub/app/notes/domain/model"
)

// NoteRepository 笔记仓库接口
type NoteRepository interface {
	// 创建笔记
	Create(ctx context.Context, note *model.Note) error
	
	// 根据ID获取笔记
	GetByID(ctx context.Context, id int64) (*model.Note, error)
	
	// 根据视频ID获取笔记列表
	GetByVideoID(ctx context.Context, videoID int64, page, pageSize int) ([]*model.Note, int64, error)
	
	// 根据用户ID获取笔记列表
	GetByUserID(ctx context.Context, userID int64, page, pageSize int) ([]*model.Note, int64, error)
	
	// 删除笔记
	Delete(ctx context.Context, id, userID int64) error
	
	// 批量获取笔记
	GetByIDs(ctx context.Context, ids []int64) ([]*model.Note, error)
	
	// 批量获取笔记统计信息
	GetStatsByIDs(ctx context.Context, ids []int64) (map[int64]*model.NoteStats, error)
}

// NoteLikeRepository 笔记点赞仓库接口
type NoteLikeRepository interface {
	// 点赞笔记
	Like(ctx context.Context, noteID, userID int64) error
	
	// 取消点赞
	Unlike(ctx context.Context, noteID, userID int64) error
	
	// 检查是否已点赞
	IsLiked(ctx context.Context, noteID, userID int64) (bool, error)
	
	// 批量检查点赞状态
	BatchIsLiked(ctx context.Context, noteIDs []int64, userID int64) (map[int64]bool, error)
	
	// 获取笔记的点赞数
	GetLikeCount(ctx context.Context, noteID int64) (int32, error)
}

// NoteCommentRepository 笔记评论仓库接口
type NoteCommentRepository interface {
	// 创建评论
	Create(ctx context.Context, comment *model.NoteComment) error
	
	// 根据笔记ID获取评论列表
	GetByNoteID(ctx context.Context, noteID int64, page, pageSize int) ([]*model.NoteComment, int64, error)
	
	// 删除评论
	Delete(ctx context.Context, id, userID int64) error
	
	// 获取笔记的评论数
	GetCommentCount(ctx context.Context, noteID int64) (int32, error)
}

// NoteFavoriteRepository 笔记收藏仓库接口
type NoteFavoriteRepository interface {
	// 收藏笔记
	Favorite(ctx context.Context, noteID, userID int64) error
	
	// 取消收藏
	Unfavorite(ctx context.Context, noteID, userID int64) error
	
	// 检查是否已收藏
	IsFavorited(ctx context.Context, noteID, userID int64) (bool, error)
	
	// 批量检查收藏状态
	BatchIsFavorited(ctx context.Context, noteIDs []int64, userID int64) (map[int64]bool, error)
	
	// 获取笔记的收藏数
	GetFavoriteCount(ctx context.Context, noteID int64) (int32, error)
	
	// 获取用户收藏的笔记列表
	GetUserFavorites(ctx context.Context, userID int64, page, pageSize int) ([]int64, int64, error)
	
	// 获取用户收藏的笔记详情列表
	GetUserFavoriteWithNoteInfo(ctx context.Context, userID int64, page, pageSize int) ([]*model.Note, int64, error)
}
