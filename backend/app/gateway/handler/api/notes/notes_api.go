package notes

import (
	"context"
	"fmt"
	"strconv"

	"github.com/cloudwego/hertz/pkg/app"

	"github.com/yxrxy/videoHub/app/gateway/pack"
	"github.com/yxrxy/videoHub/app/gateway/rpc"
	"github.com/yxrxy/videoHub/kitex_gen/notes"
	metainfoContext "github.com/yxrxy/videoHub/pkg/base/context"
	"github.com/yxrxy/videoHub/pkg/errno"
)

// CreateNote 创建笔记
// @router /api/v1/note/create [POST]
func CreateNote(ctx context.Context, c *app.RequestContext) {
	// 先将请求体绑定到map中，以便同时支持驼峰和下划线格式
	var body map[string]interface{}
	err := c.BindJSON(&body)
	if err != nil {
		pack.RespError(c, errno.ParamVerifyError.WithError(err))
		return
	}

	// 创建请求结构体
	var req notes.CreateNoteRequest

	// 手动解析参数，同时支持驼峰和下划线格式
	// 处理video_id/videoId
	if videoID, ok := body["video_id"].(float64); ok {
		videoIDInt := int64(videoID)
		req.VideoId = &videoIDInt
	} else if videoID, ok := body["videoId"].(float64); ok {
		videoIDInt := int64(videoID)
		req.VideoId = &videoIDInt
	}

	// 处理title
	if title, ok := body["title"].(string); ok {
		req.Title = title
	}

	// 处理content
	if content, ok := body["content"].(string); ok {
		req.Content = content
	}

	// 处理seconds
	if seconds, ok := body["seconds"].(float64); ok {
		secondsInt := int32(seconds)
		req.Seconds = &secondsInt
	}

	// 验证必要参数
	if req.VideoId == nil {
		pack.RespError(c, errno.ParamVerifyError.WithMessage("video_id参数不能为空"))
		return
	}
	if req.Title == "" {
		pack.RespError(c, errno.ParamVerifyError.WithMessage("title参数不能为空"))
		return
	}
	if req.Content == "" {
		pack.RespError(c, errno.ParamVerifyError.WithMessage("content参数不能为空"))
		return
	}

	// 获取用户ID（通过认证中间件设置）
	userID, err := metainfoContext.GetUserID(ctx)
	if err != nil {
		pack.RespError(c, errno.AuthInvalid.WithMessage("获取用户ID失败"))
		return
	}
	req.UserId = userID

	resp, err := rpc.CreateNoteRPC(ctx, &req)
	if err != nil {
		pack.RespError(c, err)
		return
	}

	pack.RespData(c, map[string]interface{}{
		"note_id": resp.NoteId,
	})
}

// DeleteNote 删除笔记
// @router /api/v1/note/delete [POST]
func DeleteNote(ctx context.Context, c *app.RequestContext) {
	// 先将请求体绑定到map中，以便同时支持驼峰和下划线格式
	var body map[string]interface{}
	err := c.BindJSON(&body)
	if err != nil {
		pack.RespError(c, errno.ParamVerifyError.WithError(err))
		return
	}

	// 创建请求结构体
	var req notes.DeleteNoteRequest

	// 手动解析参数，同时支持驼峰和下划线格式
	// 处理note_id/noteId
	if noteID, ok := body["note_id"].(float64); ok {
		req.NoteId = int64(noteID)
	} else if noteID, ok := body["noteId"].(float64); ok {
		req.NoteId = int64(noteID)
	}

	// 参数验证
	if req.NoteId == 0 {
		pack.RespError(c, errno.ParamVerifyError.WithError(fmt.Errorf("note_id is required")))
		return
	}

	// 获取用户ID（通过认证中间件设置）
	userID, err := metainfoContext.GetUserID(ctx)
	if err != nil {
		pack.RespError(c, errno.AuthInvalid.WithMessage("获取用户ID失败"))
		return
	}
	req.UserId = userID

	_, err = rpc.DeleteNoteRPC(ctx, &req)
	if err != nil {
		pack.RespError(c, err)
		return
	}

	pack.RespSuccess(c)
}

// GetVideoNotes 获取视频的笔记列表
// @router /api/v1/note/video [GET]
func GetVideoNotes(ctx context.Context, c *app.RequestContext) {
	// 同时支持videoId和video_id参数
	videoIDStr := c.Query("videoId")
	if videoIDStr == "" {
		videoIDStr = c.Query("video_id")
	}
	videoID, err := strconv.ParseInt(videoIDStr, 10, 64)
	if err != nil {
		pack.RespError(c, errno.ParamVerifyError.WithError(err))
		return
	}

	// 同时支持page参数，pageSize和size参数
	pageStr := c.DefaultQuery("page", "1")
	page, err := strconv.Atoi(pageStr)
	if err != nil {
		page = 1
	}
	pageSizeStr := c.DefaultQuery("pageSize", "10")
	if pageSizeStr == "10" {
		pageSizeStr = c.DefaultQuery("size", "10")
	}
	pageSize, err := strconv.Atoi(pageSizeStr)
	if err != nil {
		pageSize = 10
	}

	pageInt32 := int32(page)
	pageSizeInt32 := int32(pageSize)

	req := &notes.GetNotesRequest{
		VideoId: videoID,
		Page:    &pageInt32,
		Size:    &pageSizeInt32,
	}

	resp, err := rpc.GetNotesRPC(ctx, req)
	if err != nil {
		pack.RespError(c, err)
		return
	}

	pack.RespData(c, resp)
}

// GetUserNotes 获取用户的笔记列表
// @router /api/v1/note/user [GET]
func GetUserNotes(ctx context.Context, c *app.RequestContext) {
	// 同时支持userId和user_id参数
	userIDStr := c.Query("userId")
	if userIDStr == "" {
		userIDStr = c.Query("user_id")
	}
	userID, err := strconv.ParseInt(userIDStr, 10, 64)
	if err != nil {
		pack.RespError(c, errno.ParamVerifyError.WithError(err))
		return
	}

	// 同时支持page参数，pageSize和size参数
	pageStr := c.DefaultQuery("page", "1")
	page, err := strconv.Atoi(pageStr)
	if err != nil {
		page = 1
	}
	pageSizeStr := c.DefaultQuery("pageSize", "10")
	if pageSizeStr == "10" {
		pageSizeStr = c.DefaultQuery("size", "10")
	}
	pageSize, err := strconv.Atoi(pageSizeStr)
	if err != nil {
		pageSize = 10
	}

	pageInt32 := int32(page)
	pageSizeInt32 := int32(pageSize)

	req := &notes.GetUserNotesRequest{
		UserId: userID,
		Page:   &pageInt32,
		Size:   &pageSizeInt32,
	}

	resp, err := rpc.GetUserNotesRPC(ctx, req)
	if err != nil {
		pack.RespError(c, err)
		return
	}

	pack.RespData(c, resp)
}

// LikeNote 点赞笔记
// @router /api/v1/note/like [POST]
func LikeNote(ctx context.Context, c *app.RequestContext) {
	// 先将请求体绑定到map中，以便同时支持驼峰和下划线格式
	var body map[string]interface{}
	err := c.BindJSON(&body)
	if err != nil {
		pack.RespError(c, errno.ParamVerifyError.WithError(err))
		return
	}

	// 创建请求结构体
	var req notes.LikeNoteRequest

	// 手动解析参数，同时支持驼峰和下划线格式
	// 处理note_id/noteId
	if noteID, ok := body["note_id"].(float64); ok {
		req.NoteId = int64(noteID)
	} else if noteID, ok := body["noteId"].(float64); ok {
		req.NoteId = int64(noteID)
	}

	// 参数验证
	if req.NoteId == 0 {
		pack.RespError(c, errno.ParamVerifyError.WithError(fmt.Errorf("note_id is required")))
		return
	}

	// 获取用户ID（通过认证中间件设置）
	userID, err := metainfoContext.GetUserID(ctx)
	if err != nil {
		pack.RespError(c, errno.AuthInvalid.WithMessage("获取用户ID失败"))
		return
	}
	req.UserId = userID

	_, err = rpc.LikeNoteRPC(ctx, &req)
	if err != nil {
		pack.RespError(c, err)
		return
	}

	pack.RespSuccess(c)
}

// FavoriteNote 收藏笔记
// @router /api/v1/note/favorite [POST]
func FavoriteNote(ctx context.Context, c *app.RequestContext) {
	// 先将请求体绑定到map中，以便同时支持驼峰和下划线格式
	var body map[string]interface{}
	err := c.BindJSON(&body)
	if err != nil {
		pack.RespError(c, errno.ParamVerifyError.WithError(err))
		return
	}

	// 创建请求结构体
	var req notes.FavoriteNoteRequest

	// 手动解析参数，同时支持驼峰和下划线格式
	// 处理note_id/noteId
	if noteID, ok := body["note_id"].(float64); ok {
		req.NoteId = int64(noteID)
	} else if noteID, ok := body["noteId"].(float64); ok {
		req.NoteId = int64(noteID)
	}

	// 参数验证
	if req.NoteId == 0 {
		pack.RespError(c, errno.ParamVerifyError.WithError(fmt.Errorf("note_id is required")))
		return
	}

	// 获取用户ID（通过认证中间件设置）
	userID, err := metainfoContext.GetUserID(ctx)
	if err != nil {
		pack.RespError(c, errno.AuthInvalid.WithMessage("获取用户ID失败"))
		return
	}
	req.UserId = userID

	_, err = rpc.FavoriteNoteRPC(ctx, &req)
	if err != nil {
		pack.RespError(c, err)
		return
	}

	pack.RespSuccess(c)
}

// GetNotes 统一处理笔记查询，根据type参数转发
// @router /api/v1/note [GET]
func GetNotes(ctx context.Context, c *app.RequestContext) {
	// 获取type参数
	noteType := c.Query("type")

	// 根据type参数验证必要的参数
	switch noteType {
	case "用户笔记":
		// 用户笔记类型，验证userId或user_id参数
		userIDStr := c.Query("userId")
		if userIDStr == "" {
			userIDStr = c.Query("user_id")
		}
		if userIDStr == "" {
			pack.RespError(c, errno.ParamVerifyError.WithMessage("user_id参数不能为空"))
			return
		}
		// 调用GetUserNotes
		GetUserNotes(ctx, c)
	default:
		// 视频笔记类型，验证videoId或video_id参数
		videoIDStr := c.Query("videoId")
		if videoIDStr == "" {
			videoIDStr = c.Query("video_id")
		}
		if videoIDStr == "" {
			pack.RespError(c, errno.ParamVerifyError.WithMessage("video_id参数不能为空"))
			return
		}
		// 调用GetVideoNotes
		GetVideoNotes(ctx, c)
	}
}
