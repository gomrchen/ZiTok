package model

import "github.com/mutezebra/tiktok/pkg/errno"

// interaction
var (
	DatabaseLikeCommentError                 = errno.New(DatabaseLikeComment, "database like comment failed")
	DatabaseLikeVideoError                   = errno.New(DatabaseLikeVideo, "database like video failed")
	DatabaseWhetherCommentLikeItemExistError = errno.New(DatabaseWhetherCommentLikeItemExist, "database whether comment like item exist failed")
	CommentAlreadyLikedError                 = errno.New(CommentAlreadyLiked, "comment already liked")
	DatabaseWhetherVideoLikeItemExistError   = errno.New(DatabaseWhetherVideoLikeItemExist, "database if video like item exist failed")
	VideoAlreadyLikedError                   = errno.New(VideoAlreadyLiked, "video already liked")
	DatabaseIfCommentExistError              = errno.New(DatabaseIfCommentExist, "database if comment exist failed")
	CommentNotExistError                     = errno.New(CommentNotExist, "comment not exist")
	DatabaseIfVideoExistError                = errno.New(DatabaseIfVideoExist, "database if video exist failed")
	VideoNotExistError                       = errno.New(VideoNotExist, "video not exist")

	DatabaseDislikeCommentError = errno.New(DatabaseDislikeComment, "database dislike comment failed")
	DatabaseDislikeVideoError   = errno.New(DatabaseDislikeVideo, "database dislike video failed")

	DatabaseLikeListError = errno.New(DatabaseLikeList, "database get like list failed")

	DatabaseGetCommentRootIDError = errno.New(DatabaseGetCommentRootID, "database get comment root id failed")
	DatabaseCreateCommentError    = errno.New(DatabaseCreateComment, "database create comment failed")

	DatabaseGetCommentListError = errno.New(DatabaseGetCommentList, "database get comment list failed")

	DatabaseDeleteCommentError = errno.New(DatabaseDeleteComment, "database delete comment failed")
)
