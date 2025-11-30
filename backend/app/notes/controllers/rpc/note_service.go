package rpc

import (
    "context"
    "fmt"

    "github.com/yxrxy/videoHub/app/notes/domain/service"
    "github.com/yxrxy/videoHub/app/notes/usecase"
    "github.com/yxrxy/videoHub/kitex_gen/model"
    "github.com/yxrxy/videoHub/kitex_gen/notes"
    "github.com/yxrxy/videoHub/pkg/errno"
)

// NoteServiceHandler 笔记服务处理器
type NoteServiceHandler struct {
	noteUsecase *usecase.NoteUsecase
}

// NewNoteServiceHandler 创建笔记服务处理器实例
func NewNoteServiceHandler(noteUsecase *usecase.NoteUsecase) *NoteServiceHandler {
	return &NoteServiceHandler{
		noteUsecase: noteUsecase,
	}
}

// CreateNote 创建笔记
func (h *NoteServiceHandler) CreateNote(ctx context.Context, req *notes.CreateNoteRequest) (*notes.CreateNoteResponse, error) {
	// 转换请求参数
	createReq := &service.CreateNoteReq{
		UserID:  req.UserId,
		Title:   req.Title,
		Content: req.Content,
	}

	// 处理可选字段
	if req.VideoId != nil {
		createReq.VideoID = *req.VideoId
	}
	if req.RelatedUserId != nil {
		createReq.RelatedUserID = *req.RelatedUserId
	}
	if req.Seconds != nil {
		createReq.Seconds = *req.Seconds
	}

	// 调用用例创建笔记
	noteModel, err := h.noteUsecase.CreateNote(ctx, createReq)
	if err != nil {
		return nil, fmt.Errorf("create note failed: %w", err)
	}

	// 转换响应
	resp := &notes.CreateNoteResponse{
		NoteId: &noteModel.ID,
	}

	return resp, nil
}

// GetNotes 根据视频ID获取笔记列表
func (h *NoteServiceHandler) GetNotes(ctx context.Context, req *notes.GetNotesRequest) (*notes.GetNotesResponse, error) {
	// 设置默认分页参数
	page := 1
	if req.Page != nil {
		page = int(*req.Page)
	}
	size := 10
	if req.Size != nil {
		size = int(*req.Size)
	}

	// 调用用例获取笔记列表
    notesList, total, err := h.noteUsecase.GetVideoNotes(ctx, req.VideoId, page, size)
    if err != nil {
        return &notes.GetNotesResponse{Base: &model.BaseResp{Code: errno.InternalServiceErrorCode, Msg: err.Error()}}, nil
    }

	// 转换响应
	resp := &notes.GetNotesResponse{
		Total: int64(total),
		Notes: make([]*notes.NoteInfo, 0, len(notesList)),
	}

	for _, n := range notesList {
		// 转换统计字段
		likeCount := int32(n.LikeCount)
		commentCount := int32(n.CommentCount)
		favoriteCount := int32(n.FavoriteCount)
		createdAt := int64(n.CreatedAt.Unix())
		var updatedAt *int64
		if !n.UpdatedAt.IsZero() {
			updatedAtVal := int64(n.UpdatedAt.Unix())
			updatedAt = &updatedAtVal
		}
		
		// 转换可选字段
		var videoId *int64
		if n.VideoID != 0 {
			videoId = &n.VideoID
		}
		var relatedUserId *int64
		if n.RelatedUserID != 0 {
			relatedUserId = &n.RelatedUserID
		}
		var seconds *int32
		if n.Seconds != 0 {
			seconds = &n.Seconds
		}

		noteInfo := &notes.NoteInfo{
			Id:            n.ID,
			UserId:        n.UserID,
			VideoId:       videoId,
			RelatedUserId: relatedUserId,
			Title:         n.Title,
			Content:       n.Content,
			Seconds:       seconds,
			LikeCount:     &likeCount,
			CommentCount:  &commentCount,
			FavoriteCount: &favoriteCount,
			CreatedAt:     createdAt,
			UpdatedAt:     updatedAt,
		}
		resp.Notes = append(resp.Notes, noteInfo)
	}

	return resp, nil
}

// DeleteNote 删除笔记
func (h *NoteServiceHandler) DeleteNote(ctx context.Context, req *notes.DeleteNoteRequest) (*notes.DeleteNoteResponse, error) {
	// 调用用例删除笔记
	err := h.noteUsecase.DeleteNote(ctx, req.NoteId, req.UserId)
	if err != nil {
		return nil, fmt.Errorf("delete note failed: %w", err)
	}

	return &notes.DeleteNoteResponse{}, nil
}

// LikeNote 点赞笔记
func (h *NoteServiceHandler) LikeNote(ctx context.Context, req *notes.LikeNoteRequest) (*notes.LikeNoteResponse, error) {
	// 调用用例点赞笔记
    err := h.noteUsecase.LikeNote(ctx, req.NoteId, req.UserId)
    if err != nil {
        return &notes.LikeNoteResponse{Base: &model.BaseResp{Code: errno.InternalServiceErrorCode, Msg: err.Error()}}, nil
    }

	return &notes.LikeNoteResponse{}, nil
}

// FavoriteNote 收藏笔记
func (h *NoteServiceHandler) FavoriteNote(ctx context.Context, req *notes.FavoriteNoteRequest) (*notes.FavoriteNoteResponse, error) {
	// 调用用例收藏笔记
    err := h.noteUsecase.FavoriteNote(ctx, req.NoteId, req.UserId)
    if err != nil {
        return &notes.FavoriteNoteResponse{Base: &model.BaseResp{Code: errno.InternalServiceErrorCode, Msg: err.Error()}}, nil
    }

	return &notes.FavoriteNoteResponse{}, nil
}

// GetUserNotes 获取用户的笔记列表
func (h *NoteServiceHandler) GetUserNotes(ctx context.Context, req *notes.GetUserNotesRequest) (*notes.GetUserNotesResponse, error) {
	// 设置默认分页参数
	page := 1
	if req.Page != nil {
		page = int(*req.Page)
	}
	size := 10
	if req.Size != nil {
		size = int(*req.Size)
	}

	// 调用用例获取用户笔记列表
    notesList, total, err := h.noteUsecase.GetUserNotes(ctx, req.UserId, page, size)
    if err != nil {
        return &notes.GetUserNotesResponse{Base: &model.BaseResp{Code: errno.InternalServiceErrorCode, Msg: err.Error()}}, nil
    }

	// 转换响应
	resp := &notes.GetUserNotesResponse{
		Total: int64(total),
		Notes: make([]*notes.NoteInfo, 0, len(notesList)),
	}

	for _, n := range notesList {
		// 转换统计字段
		likeCount := int32(n.LikeCount)
		commentCount := int32(n.CommentCount)
		favoriteCount := int32(n.FavoriteCount)
		createdAt := int64(n.CreatedAt.Unix())
		var updatedAt *int64
		if !n.UpdatedAt.IsZero() {
			updatedAtVal := int64(n.UpdatedAt.Unix())
			updatedAt = &updatedAtVal
		}
		
		// 转换可选字段
		var videoId *int64
		if n.VideoID != 0 {
			videoId = &n.VideoID
		}
		var relatedUserId *int64
		if n.RelatedUserID != 0 {
			relatedUserId = &n.RelatedUserID
		}
		var seconds *int32
		if n.Seconds != 0 {
			seconds = &n.Seconds
		}

		// 转换笔记信息
		noteInfo := &notes.NoteInfo{
			Id:            n.ID,
			UserId:        n.UserID,
			VideoId:       videoId,
			RelatedUserId: relatedUserId,
			Title:         n.Title,
			Content:       n.Content,
			Seconds:       seconds,
			LikeCount:     &likeCount,
			CommentCount:  &commentCount,
			FavoriteCount: &favoriteCount,
			CreatedAt:     createdAt,
			UpdatedAt:     updatedAt,
		}
		resp.Notes = append(resp.Notes, noteInfo)
	}

	return resp, nil
}
