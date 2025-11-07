package service

import (
	"github.com/ozline/tiktok/cmd/video/dal/db"
	"github.com/ozline/tiktok/cmd/video/rpc"
	"github.com/ozline/tiktok/kitex_gen/follow"
	"github.com/ozline/tiktok/kitex_gen/interaction"
	"github.com/ozline/tiktok/kitex_gen/user"
	"github.com/ozline/tiktok/kitex_gen/video"
	"github.com/ozline/tiktok/pkg/utils"
	"golang.org/x/sync/errgroup"
)

func (s *VideoService) GetFriendVideoList(req *video.GetFriendVideoListRequest) ([]db.Video, []*user.User, []int64, []int64, []bool, error) {
	claim, err := utils.CheckToken(req.Token)
	if err != nil {
		return nil, nil, nil, nil, nil, err
	}

	// 获取好友列表
	friendListResp, err := rpc.GetFriendList(s.ctx, &follow.FriendListRequest{
		UserId: claim.UserId,
		Token:  req.Token,
	})
	if err != nil {
		return nil, nil, nil, nil, nil, err
	}

	// 提取好友ID列表
	friendIDs := make([]int64, 0, len(friendListResp))
	for _, friend := range friendListResp {
		friendIDs = append(friendIDs, friend.User.Id)
	}

	if len(friendIDs) == 0 {
		return []db.Video{}, []*user.User{}, []int64{}, []int64{}, []bool{}, nil
	}

	// 获取好友发布的视频
	videoList, err := db.GetVideoInfoByFriendIDs(s.ctx, friendIDs)
	if err != nil {
		return nil, nil, nil, nil, nil, err
	}

	// 创建错误组
	var eg errgroup.Group
	type result struct {
		userInfo      *user.User
		favoriteCount int64
		commentCount  int64
		isFavorite    bool
	}

	results := make([]result, len(videoList))

	// 并发调用获取user信息、favoriteCount、commentCount和isFavorite
	for i := 0; i < len(videoList); i++ {
		index := i // 在闭包中使用本地副本以避免竞态条件
		eg.Go(func() error {
			// 获取user信息
			userInfo, err := rpc.GetUser(s.ctx, &user.InfoRequest{
				UserId: videoList[index].UserID,
				Token:  req.Token,
			})
			if err != nil {
				return err
			}
			// 获取favoriteCount
			favoriteCount, err := rpc.GetVideoFavoriteCount(s.ctx, &interaction.VideoFavoritedCountRequest{
				VideoId: videoList[index].Id,
				Token:   req.Token,
			})
			if err != nil {
				return err
			}
			// 获取commentCount
			commentCount, err := rpc.GetCommentCount(s.ctx, &interaction.CommentCountRequest{
				VideoId: videoList[index].Id,
				Token:   &req.Token,
			})
			if err != nil {
				return err
			}
			// 获取isFavorite
			isFavorite, err := rpc.GetVideoIsFavorite(s.ctx, &interaction.InteractionServiceIsFavoriteArgs{Req: &interaction.IsFavoriteRequest{
				UserId:  claim.UserId,
				VideoId: videoList[index].Id,
				Token:   req.Token,
			}})
			if err != nil {
				return err
			}
			results[index] = result{
				userInfo:      userInfo,
				favoriteCount: favoriteCount,
				commentCount:  commentCount,
				isFavorite:    isFavorite,
			}
			return nil
		})
	}

	// 等待所有goroutine完成
	if err := eg.Wait(); err != nil {
		return nil, nil, nil, nil, nil, err
	}
	var userList []*user.User
	var favoriteCountList []int64
	var commentCountList []int64
	var isFavoriteList []bool

	for _, result := range results {
		userList = append(userList, result.userInfo)
		favoriteCountList = append(favoriteCountList, result.favoriteCount)
		commentCountList = append(commentCountList, result.commentCount)
		isFavoriteList = append(isFavoriteList, result.isFavorite)
	}

	return videoList, userList, favoriteCountList, commentCountList, isFavoriteList, nil
}

