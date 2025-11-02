package rpc

import (
	"context"

	"github.com/mutezebra/tiktok/pkg/kitex_gen/api/interaction"
)

// rpc client
func Like(ctx context.Context, req *interaction.LikeReq) (r *interaction.LikeResp, err error) {
	r, err = InteractionClient.Like(ctx, req)
	return
}

func DisLike(ctx context.Context, req *interaction.DislikeReq) (r *interaction.DislikeResp, err error) {
	r, err = InteractionClient.Dislike(ctx, req)
	return
}

func LikeList(ctx context.Context, req *interaction.LikeListReq) (r *interaction.LikeListResp, err error) {
	r, err = InteractionClient.LikeList(ctx, req)
	return
}

func Comment(ctx context.Context, req *interaction.CommentReq) (r *interaction.CommentResp, err error) {
	r, err = InteractionClient.Comment(ctx, req)
	return
}

func CommentList(ctx context.Context, req *interaction.CommentListReq) (r *interaction.CommentListResp, err error) {
	r, err = InteractionClient.CommentList(ctx, req)
	return
}

func DeleteComment(ctx context.Context, req *interaction.DeleteCommentReq) (r *interaction.DeleteCommentResp, err error) {
	r, err = InteractionClient.DeleteComment(ctx, req)
	return
}
