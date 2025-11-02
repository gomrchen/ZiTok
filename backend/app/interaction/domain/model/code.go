package model

// Interaction
const (
	DatabaseLikeComment                 = 30000
	DatabaseLikeVideo                   = 30001
	DatabaseWhetherCommentLikeItemExist = 30002
	CommentAlreadyLiked                 = 30003
	DatabaseWhetherVideoLikeItemExist   = 30004
	VideoAlreadyLiked                   = 30005
	DatabaseIfCommentExist              = 30006
	CommentNotExist                     = 30007
	DatabaseIfVideoExist                = 30008
	VideoNotExist                       = 30009

	DatabaseDislikeComment = 30010
	DatabaseDislikeVideo   = 30011

	DatabaseLikeList = 30020

	DatabaseGetCommentRootID = 30030
	DatabaseCreateComment    = 30031

	DatabaseGetCommentList = 30040

	DatabaseDeleteComment = 30050
)
