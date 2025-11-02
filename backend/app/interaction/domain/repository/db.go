package repository

import (
	"context"

	"github.com/mutezebra/tiktok/pkg/types"
)

type (
	Comment types.Comment
	Video   types.Video
)

type InteractionRepository interface {
	CreateComment(ctx context.Context, comment *Comment) error
	LikeComment(ctx context.Context, uid, cid int64) error    // like a comment
	DislikeComment(ctx context.Context, uid, cid int64) error // dislike a comment
	DeleteComment(ctx context.Context, uid, cid int64) error  // delete a comment
	GetCommentRootID(ctx context.Context, cid int64) (int64, error)
	GetCommentList(ctx context.Context, cid int64, page int8, size int8) ([]Comment, error)
	WhetherCommentLikeItemExist(ctx context.Context, uid, cid int64) (bool, error) // check if the user has liked the video
	WhetherCommentExist(ctx context.Context, cid int64) (bool, error)

	LikeVideo(ctx context.Context, uid, vid int64) error                                               // like a video
	DislikeVideo(ctx context.Context, uid, vid int64) error                                            // dislike a video
	LikeList(ctx context.Context, uid int64, page int8, size int8) ([]Video, error)                    // get the user's like list
	GetVideoDirectCommentList(ctx context.Context, vid int64, page int8, size int8) ([]Comment, error) // get a video's comment list
	WhetherVideoLikeItemExist(ctx context.Context, uid, vid int64) (bool, error)                       // check if the user has liked the video
	WhetherVideoExist(ctx context.Context, vid int64) (bool, error)
}
