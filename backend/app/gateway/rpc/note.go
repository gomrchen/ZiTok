package rpc

import (
	"context"
	"log"

	"github.com/yxrxy/videoHub/kitex_gen/notes"
	"github.com/yxrxy/videoHub/pkg/errno"
)

// CreateNoteRPC 创建笔记
func CreateNoteRPC(ctx context.Context, req *notes.CreateNoteRequest) (*notes.CreateNoteResponse, error) {
	resp, err := noteClient.CreateNote(ctx, req)
	if err != nil {
		log.Printf("创建笔记RPC调用失败: %v", err)
		return nil, errno.InternalServiceError.WithError(err)
	}
	if resp.Base.Code != errno.SuccessCode {
		return nil, errno.InternalServiceError.WithMessage(resp.Base.Msg)
	}
	return resp, nil
}

// GetNotesRPC 根据视频ID获取笔记列表
func GetNotesRPC(ctx context.Context, req *notes.GetNotesRequest) (*notes.GetNotesResponse, error) {
	resp, err := noteClient.GetNotes(ctx, req)
	if err != nil {
		log.Printf("根据视频ID获取笔记列表RPC调用失败: %v", err)
		return nil, errno.InternalServiceError.WithError(err)
	}
	if resp.Base.Code != errno.SuccessCode {
		return nil, errno.InternalServiceError.WithMessage(resp.Base.Msg)
	}
	return resp, nil
}

// GetUserNotesRPC 根据用户ID获取笔记列表
func GetUserNotesRPC(ctx context.Context, req *notes.GetUserNotesRequest) (*notes.GetUserNotesResponse, error) {
	resp, err := noteClient.GetUserNotes(ctx, req)
	if err != nil {
		log.Printf("根据用户ID获取笔记列表RPC调用失败: %v", err)
		return nil, errno.InternalServiceError.WithError(err)
	}
	if resp.Base.Code != errno.SuccessCode {
		return nil, errno.InternalServiceError.WithMessage(resp.Base.Msg)
	}
	return resp, nil
}

// DeleteNoteRPC 删除笔记
func DeleteNoteRPC(ctx context.Context, req *notes.DeleteNoteRequest) (*notes.DeleteNoteResponse, error) {
	resp, err := noteClient.DeleteNote(ctx, req)
	if err != nil {
		log.Printf("删除笔记RPC调用失败: %v", err)
		return nil, errno.InternalServiceError.WithError(err)
	}
	if resp.Base.Code != errno.SuccessCode {
		return nil, errno.InternalServiceError.WithMessage(resp.Base.Msg)
	}
	return resp, nil
}

// LikeNoteRPC 点赞笔记
func LikeNoteRPC(ctx context.Context, req *notes.LikeNoteRequest) (*notes.LikeNoteResponse, error) {
	resp, err := noteClient.LikeNote(ctx, req)
	if err != nil {
		log.Printf("点赞笔记RPC调用失败: %v", err)
		return nil, errno.InternalServiceError.WithError(err)
	}
	if resp.Base.Code != errno.SuccessCode {
		return nil, errno.InternalServiceError.WithMessage(resp.Base.Msg)
	}
	return resp, nil
}

// FavoriteNoteRPC 收藏笔记
func FavoriteNoteRPC(ctx context.Context, req *notes.FavoriteNoteRequest) (*notes.FavoriteNoteResponse, error) {
	resp, err := noteClient.FavoriteNote(ctx, req)
	if err != nil {
		log.Printf("收藏笔记RPC调用失败: %v", err)
		return nil, errno.InternalServiceError.WithError(err)
	}
	if resp.Base.Code != errno.SuccessCode {
		return nil, errno.InternalServiceError.WithMessage(resp.Base.Msg)
	}
	return resp, nil
}