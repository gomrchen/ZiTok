package usecase

import (
	"context"
	"strconv"
	"time"

	"github.com/mutezebra/tiktok/app/interaction/domain/model"
	"github.com/mutezebra/tiktok/app/interaction/domain/repository"
	interactionService "github.com/mutezebra/tiktok/app/interaction/domain/service"
	"github.com/mutezebra/tiktok/app/interaction/usecase/pack"
	"github.com/mutezebra/tiktok/pkg/constants"
	"github.com/mutezebra/tiktok/pkg/kitex_gen/api/interaction"
	"github.com/mutezebra/tiktok/pkg/kitex_gen/api/video"
)

type InteractionCase struct {
	repo    repository.InteractionRepository
	service *interactionService.Service
}

func NewInteractionCase(repo repository.InteractionRepository, service *interactionService.Service) *InteractionCase {
	return &InteractionCase{
		repo:    repo,
		service: service,
	}
}

type commentDTO struct {
	cid     int64
	uid     int64
	vid     int64
	rootID  int64
	replyID int64
	content string
}

func (i *InteractionCase) Like(ctx context.Context, req *interaction.LikeReq) (r *interaction.LikeResp, err error) {
	var exist bool
	switch req.GetActionType() {
	case constants.LikeCommentActionKey:
		exist, err = i.repo.WhetherCommentLikeItemExist(ctx, req.GetUID(), req.GetCommentID())
		if err != nil {
			return nil, pack.ReturnError(model.DatabaseWhetherCommentLikeItemExistError, err)
		}
		if exist {
			return nil, pack.ReturnError(model.CommentAlreadyLikedError, nil)
		}

		exist, err = i.repo.WhetherCommentExist(ctx, req.GetCommentID())
		if err != nil {
			return nil, pack.ReturnError(model.DatabaseIfCommentExistError, err)
		}
		if !exist {
			return nil, pack.ReturnError(model.CommentNotExistError, nil)
		}

		if err = i.repo.LikeComment(ctx, req.GetUID(), req.GetCommentID()); err != nil {
			return nil, pack.ReturnError(model.DatabaseLikeCommentError, err)
		}
	case constants.LikeVideoActionKey:
		exist, err = i.repo.WhetherVideoLikeItemExist(ctx, req.GetUID(), req.GetVideoID())
		if err != nil {
			return nil, pack.ReturnError(model.DatabaseWhetherVideoLikeItemExistError, err)
		}
		if exist {
			return nil, pack.ReturnError(model.VideoAlreadyLikedError, nil)
		}

		exist, err = i.repo.WhetherVideoExist(ctx, req.GetVideoID())
		if err != nil {
			return nil, pack.ReturnError(model.DatabaseIfVideoExistError, err)
		}
		if !exist {
			return nil, pack.ReturnError(model.VideoNotExistError, nil)
		}
		if err = i.repo.LikeVideo(ctx, req.GetUID(), req.GetVideoID()); err != nil {
			return nil, pack.ReturnError(model.DatabaseLikeVideoError, err)
		}
	}
	return nil, nil
}

func (i *InteractionCase) Dislike(ctx context.Context, req *interaction.DislikeReq) (r *interaction.DislikeResp, err error) {
	switch req.GetActionType() {
	case constants.DisLikeCommentActionKey:
		if err = i.repo.DislikeComment(ctx, req.GetUID(), req.GetCommentID()); err != nil {
			return nil, pack.ReturnError(model.DatabaseDislikeCommentError, err)
		}
	case constants.DisLikeVideoActionKey:
		if err = i.repo.DislikeVideo(ctx, req.GetUID(), req.GetVideoID()); err != nil {
			return nil, pack.ReturnError(model.DatabaseDislikeVideoError, err)
		}
	}

	return nil, nil
}

func (i *InteractionCase) LikeList(ctx context.Context, req *interaction.LikeListReq) (r *interaction.LikeListResp, err error) {
	videos, err := i.repo.LikeList(ctx, req.GetUID(), req.GetPageNum(), req.GetPageSize())
	if err != nil {
		return nil, pack.ReturnError(model.DatabaseLikeListError, err)
	}

	result := make([]*video.VideoInfo, len(videos))
	for index := range videos {
		result[index] = repoV2IDL(&videos[index])
	}

	r = new(interaction.LikeListResp)
	count := int32(len(videos))
	r.SetCount(&count)
	r.SetItems(result)

	return r, nil
}

func (i *InteractionCase) Comment(ctx context.Context, req *interaction.CommentReq) (r *interaction.CommentResp, err error) {
	dto := &commentDTO{
		cid:     i.service.GenerateID(),
		uid:     req.GetUID(),
		vid:     req.GetVideoID(),
		content: req.GetContent(),
	}

	cid := i.service.GenerateID()
	if req.CommentID != nil { // 说明是对评论的评论
		dto.replyID = req.GetCommentID()
		var rootId int64
		rootId, err = i.repo.GetCommentRootID(ctx, dto.replyID)
		if err != nil {
			return nil, pack.ReturnError(model.DatabaseGetCommentRootIDError, err)
		}
		if rootId == 0 {
			rootId = cid
		}
		dto.rootID = rootId
		if err = i.repo.CreateComment(ctx, dtoC2Repo(dto)); err != nil {
			return nil, pack.ReturnError(model.DatabaseCreateCommentError, err)
		}
	} else { // 说明是对视频的评论
		dto.replyID = 0
		dto.cid = cid
		dto.rootID = 0
		if err = i.repo.CreateComment(ctx, dtoC2Repo(dto)); err != nil {
			return nil, pack.ReturnError(model.DatabaseCreateCommentError, err)
		}
	}

	return nil, nil
}

func (i *InteractionCase) CommentList(ctx context.Context, req *interaction.CommentListReq) (r *interaction.CommentListResp, err error) {
	var comments []repository.Comment
	switch {
	case req.VideoID != nil:
		comments, err = i.repo.GetVideoDirectCommentList(ctx, req.GetVideoID(), req.GetPageNum(), req.GetPageSize())
	case req.CommentID != nil:
		comments, err = i.repo.GetCommentList(ctx, req.GetCommentID(), req.GetPageNum(), req.GetPageSize())
	default:
		return nil, err
	}
	if err != nil {
		return nil, pack.ReturnError(model.DatabaseGetCommentListError, err)
	}

	commentInfos := make([]*interaction.CommentInfo, len(comments))
	for index := range comments {
		commentInfos[index] = repoC2IDL(&comments[index])
	}

	r = new(interaction.CommentListResp)
	length := int32(len(comments))
	r.SetCount(&length)
	r.SetItems(commentInfos)

	return r, nil
}

func (i *InteractionCase) DeleteComment(ctx context.Context, req *interaction.DeleteCommentReq) (r *interaction.DeleteCommentResp, err error) {
	if err = i.repo.DeleteComment(ctx, req.GetUID(), req.GetCommentID()); err != nil {
		return nil, pack.ReturnError(model.DatabaseDeleteCommentError, err)
	}

	return nil, nil
}

func dtoC2Repo(dto *commentDTO) *repository.Comment {
	return &repository.Comment{
		ID:       dto.cid,
		UID:      dto.uid,
		VID:      dto.vid,
		RootID:   dto.rootID,
		ReplyID:  dto.replyID,
		Likes:    0,
		Content:  dto.content,
		CreateAt: time.Now().Unix(),
		DeleteAt: 0,
	}
}

func repoC2IDL(comment *repository.Comment) *interaction.CommentInfo {
	id := strconv.FormatInt(comment.ID, 10)
	vid := strconv.FormatInt(comment.VID, 10)
	uid := strconv.FormatInt(comment.UID, 10)
	replyID := strconv.FormatInt(comment.ReplyID, 10)
	rootID := strconv.FormatInt(comment.RootID, 10)
	createAt := time.Unix(comment.CreateAt, 0).Format("2006-01-02 15:04:05")
	return &interaction.CommentInfo{
		ID:       &id,
		UID:      &uid,
		VID:      &vid,
		RootID:   &rootID,
		ReplyID:  &replyID,
		Content:  &comment.Content,
		Likes:    &comment.Likes,
		CreateAt: &createAt,
	}
}

func repoV2IDL(repo *repository.Video) *video.VideoInfo {
	vid := strconv.FormatInt(repo.ID, 10)
	uid := strconv.FormatInt(repo.UID, 10)
	return &video.VideoInfo{
		ID:       &vid,
		UID:      &uid,
		VideoURL: &repo.VideoURL,
		CoverURL: &repo.CoverURL,
		Intro:    &repo.Intro,
		Title:    &repo.Title,
		Starts:   &repo.Starts,
		Likes:    &repo.Likes,
		Views:    &repo.Views,
	}
}
