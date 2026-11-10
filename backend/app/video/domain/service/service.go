package service

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/bytedance/gopkg/util/logger"
	"github.com/bytedance/sonic"
	"github.com/yxrxy/videoHub/app/video/domain/model"
	"github.com/yxrxy/videoHub/config"
	pkgcontext "github.com/yxrxy/videoHub/pkg/base/context"
	"github.com/yxrxy/videoHub/pkg/constants"
)

func (s *VideoService) CheckVideo(_ context.Context, videoData []byte, contentType string) bool {
	// 检查视频大小
	if len(videoData) > config.Upload.Video.MaxSize {
		return false
	}

	// 校验视频类型
	if !s.isValidVideoType(contentType) {
		return false
	}

	if err := os.MkdirAll(config.Upload.Video.UploadDir, constants.DirPermission); err != nil {
		return false
	}

	return true
}

func (s *VideoService) SaveVideo(ctx context.Context, userID int64, videoData []byte,
	contentType string, title string, description, category *string, tags []string, isPrivate bool,
) (string, error) {
	// 1. 保存视频文件
	ext := ".mp4"
	switch contentType {
	case "video/mp4":
		ext = ".mp4"
	case "video/quicktime":
		ext = ".mov"
	}
	timestamp := time.Now().Unix()
	filename := fmt.Sprintf("%d_%d%s", userID, timestamp, ext)
	videoPath := filepath.Join(config.Upload.Video.UploadDir, filename)

	if err := os.WriteFile(videoPath, videoData, constants.FilePermission); err != nil {
		return "", fmt.Errorf("保存视频失败: %w", err)
	}

	// 2. 创建视频记录
	videoURL := fmt.Sprintf("%s/%s", config.Upload.Video.BaseURL, filename)
	video := &model.Video{
		UserID:      userID,
		VideoURL:    videoURL,
		Title:       title,
		Description: *description,
		Category:    *category,
		Tags:        strings.Join(tags, ","),
		IsPrivate:   isPrivate,
	}

	// 3. 存入数据库
	if err := s.db.CreateVideo(ctx, video); err != nil {
		if removeErr := os.Remove(videoPath); removeErr != nil {
			return "", removeErr
		}
		return "", fmt.Errorf("保存视频记录失败: %w", err)
	}

	// 4. 处理视频信息（封面、时长等）
	go func() {
		if err := s.SendProcessVideoMsg(ctx, video, videoPath); err != nil {
			log.Printf("failed to send video processing message: %v", err)
		}
	}()
	user, err := s.userDB.GetUserByID(ctx, userID)
	if err != nil {
		return "", err
	}
	err = s.es.AddItem(ctx, "video", video, user.Username)
	if err != nil {
		return "", err
	}

	err = s.IndexVideo(ctx, video, user.Username)
	if err != nil {
		return "", err
	}
	if s.recommender != nil {
		go func(v *model.Video) {
			_ = s.recommender.InsertItem(context.Background(), v)
		}(video)
	}
	return videoPath, nil
}

func (s *VideoService) ReportFeedback(ctx context.Context, userID int64, videoID int64, feedbackType string, ts time.Time) {
	if s.recommender == nil {
		return
	}
	go func() {
		_ = s.recommender.InsertFeedback(context.Background(), userID, videoID, feedbackType, ts)
	}()
}

func (s *VideoService) processVideo(ctx context.Context, videoID int64, videoPath string) error {
	// 1. 确保封面目录存在
	coverDir := "/home/ZiTok/src/storage/covers"
	if err := os.MkdirAll(coverDir, constants.DirPermission); err != nil {
		return fmt.Errorf("创建封面目录失败: %w", err)
	}

	// 2. 生成封面
	coverFilename := strings.TrimSuffix(filepath.Base(videoPath), filepath.Ext(videoPath)) + "_cover.jpg"
	coverPath := filepath.Join(coverDir, coverFilename)
	cmd := exec.Command("ffmpeg",
		"-i", videoPath, // 输入文件
		"-ss", "00:00:01", // 在1秒处截图
		"-vframes", "1", // 只截取1帧
		"-q:v", "2", // 高质量
		coverPath, // 输出文件
	)

	// 收集命令输出
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("生成封面失败，命令输出：%s，错误：%w", string(output), err)
	}

	// 2. 获取视频时长
	durationCmd := exec.Command("ffprobe",
		"-v", "quiet",
		"-show_entries", "format=duration",
		"-of", "default=noprint_wrappers=1:nokey=1",
		videoPath,
	)
	output, err = durationCmd.Output()
	if err != nil {
		return fmt.Errorf("获取视频时长失败: %w", err)
	}
	duration, err := strconv.ParseFloat(strings.TrimSpace(string(output)), 64)
	if err != nil {
		return fmt.Errorf("解析视频时长失败: %w", err)
	}

	// 3. 上传封面到存储系统
	coverFilename = filepath.Base(coverPath)
	coverURL := fmt.Sprintf("%s/%s", config.Upload.Video.BaseURL, coverFilename)
	if err := os.Rename(coverPath, filepath.Join(config.Upload.Video.CoverDir, coverFilename)); err != nil {
		logger.Errorf("移动封面文件失败：%v", err)
		return fmt.Errorf("移动封面文件失败: %w", err)
	}

	// 4. 更新数据库
	video := &model.Video{
		ID:       videoID,
		CoverURL: coverURL,
		Duration: int64(duration),
	}
	if err := s.db.UpdateVideo(ctx, video); err != nil {
		logger.Errorf("更新视频信息失败：%v", err)
		return fmt.Errorf("更新视频信息失败: %w", err)
	}

	return nil
}

func (s *VideoService) SendProcessVideoMsg(ctx context.Context, video *model.Video, videoPath string) error {
	if video == nil {
		return fmt.Errorf("视频对象为空")
	}

	if videoPath == "" {
		return fmt.Errorf("视频路径为空")
	}

	if err := s.mq.SendProcessVideo(ctx, video.ID, videoPath); err != nil {
		return fmt.Errorf("发送视频处理消息失败: %w", err)
	}

	return nil
}

func (s *VideoService) ConsumeProcessVideo(ctx context.Context) {
	msgCh := s.mq.ConsumeProcessVideo(ctx)
	go func() {
		for msg := range msgCh {
			req := new(model.ProcessVideoMsg)
			err := sonic.Unmarshal(msg.V, req)
			if err != nil {
				logger.Errorf("VideoService.ConsumeProcessVideo: Unmarshal err: %v", err)
			}
			err = s.processVideo(ctx, req.VideoID, req.VideoPath)
			if err != nil {
				logger.Errorf("VideoService.ConsumeProcessVideo: processVideo err: %v", err)
			}
		}
	}()
}

func (s *VideoService) isValidVideoType(contentType string) bool {
	validTypes := map[string]bool{
		"video/mp4":       true,
		"video/quicktime": true,
	}
	return validTypes[contentType]
}

func (s *VideoService) GetVideoList(ctx context.Context, userID int64, page int64, size int32,
	category *string,
) ([]*model.Video, int64, error) {
	if page <= 0 {
		page = 1
	}
	if size <= 0 {
		size = 10
	}

	videos, total, err := s.db.GetVideoList(ctx, userID, page, size, category)
	if err != nil {
		return nil, 0, err
	}

	result := make([]*model.Video, 0, len(videos))
	for _, v := range videos {
		result = append(result, &model.Video{
			ID:           v.ID,
			UserID:       v.UserID,
			VideoURL:     v.VideoURL,
			CoverURL:     v.CoverURL,
			Title:        v.Title,
			Description:  v.Description,
			Duration:     v.Duration,
			Category:     v.Category,
			Tags:         v.Tags,
			VisitCount:   v.VisitCount,
			LikeCount:    v.LikeCount,
			CommentCount: v.CommentCount,
			IsPrivate:    v.IsPrivate,
		})
	}

	return result, total, nil
}

func (s *VideoService) GetVideoDetail(ctx context.Context, videoID, userID int64) (*model.Video, error) {
	v, err := s.db.GetVideoByID(ctx, videoID)
	if err != nil {
		return nil, err
	}
	result := &model.Video{
		ID:           v.ID,
		UserID:       v.UserID,
		VideoURL:     v.VideoURL,
		CoverURL:     v.CoverURL,
		Title:        v.Title,
		Description:  v.Description,
		Duration:     v.Duration,
		Category:     v.Category,
		Tags:         v.Tags,
		VisitCount:   v.VisitCount,
		LikeCount:    v.LikeCount,
		CommentCount: v.CommentCount,
		IsPrivate:    v.IsPrivate,
	}
	return result, nil
}

func (s *VideoService) GetHotVideos(
	ctx context.Context,
	limit int32,
	category string,
	lastVisit, lastLike, lastID int64,
) ([]*model.Video, int64, int64, int64, int64, error) {
	videos, total, nextVisit, nextLike, nextID, err := s.db.GetHotVideos(
		ctx, limit, category, lastVisit, lastLike, lastID)
	if err != nil {
		return nil, 0, 0, 0, 0, err
	}

	var res []*model.Video
	for _, v := range videos {
		res = append(res, &model.Video{
			ID:           v.ID,
			UserID:       v.UserID,
			VideoURL:     v.VideoURL,
			CoverURL:     v.CoverURL,
			Title:        v.Title,
			Description:  v.Description,
			Duration:     v.Duration,
			Category:     v.Category,
			Tags:         v.Tags,
			VisitCount:   v.VisitCount,
			LikeCount:    v.LikeCount,
			CommentCount: v.CommentCount,
			IsPrivate:    v.IsPrivate,
		})
	}
	return res, total, nextVisit, nextLike, nextID, nil
}

func (s *VideoService) RecommendVideos(
	ctx context.Context,
	limit int32,
) ([]*model.Video, error) {
	if s.recommender != nil {
		if uid, err := pkgcontext.GetUserID(ctx); err == nil && uid > 0 {
			ids, err := s.recommender.Recommend(ctx, uid, int(limit))
			if err == nil && len(ids) > 0 {
				var res []*model.Video
				for _, id := range ids {
					v, err := s.db.GetVideoByID(ctx, id)
					if err == nil && v != nil {
						res = append(res, &model.Video{
							ID:           v.ID,
							UserID:       v.UserID,
							VideoURL:     v.VideoURL,
							CoverURL:     v.CoverURL,
							Title:        v.Title,
							Description:  v.Description,
							Duration:     v.Duration,
							Category:     v.Category,
							Tags:         v.Tags,
							VisitCount:   v.VisitCount,
							LikeCount:    v.LikeCount,
							CommentCount: v.CommentCount,
							IsPrivate:    v.IsPrivate,
						})
					}
				}
				if len(res) > 0 {
					return res, nil
				}
			}
		}
	}
	return nil, nil
}

// GenerateVideoEmbedding 为视频生成向量表示
func (s *VideoService) GenerateVideoEmbedding(ctx context.Context, videoID int64) error {
	// 获取视频信息
	video, err := s.db.GetVideoByID(ctx, videoID)
	if err != nil {
		return fmt.Errorf("获取视频失败: %w", err)
	}

	// 构建用于嵌入的文本
	embedText := fmt.Sprintf("%s %s %s",
		video.Title,
		video.Description,
		video.Tags)

	// 生成嵌入
	embedding, err := s.embedding.GenerateEmbedding(ctx, embedText)
	if err != nil {
		return fmt.Errorf("生成嵌入失败: %w", err)
	}

	// 准备元数据
	var tags []string
	if video.Tags != "" {
		tags = strings.Split(video.Tags, ",")
	}

	metadata := &model.VideoMetadata{
		Title:       video.Title,
		Description: video.Description,
		Tags:        tags,
		Category:    video.Category,
		UserID:      video.UserID,
	}

	// 存储向量
	err = s.vectorDB.StoreVector(ctx, video.ID, embedding, metadata)
	if err != nil {
		return fmt.Errorf("存储向量失败: %w", err)
	}

	return nil
}

// GenerateEmbeddingsForAllVideos 为所有视频批量生成向量
func (s *VideoService) GenerateEmbeddingsForAllVideos(ctx context.Context) {
	page := int64(constants.DefaultPage)
	size := int32(constants.MaxPageSize)
	for {
		videos, total, err := s.db.GetVideoList(ctx, 0, page, size, nil)
		if err != nil {
			logger.Errorf("获取视频列表失败: %v", err)
			return
		}

		for _, video := range videos {
			err := s.GenerateVideoEmbedding(ctx, video.ID)
			if err != nil {
				logger.Errorf("为视频 %d 生成向量失败: %v", video.ID, err)
			} else {
				logger.Infof("成功为视频 %d 生成向量", video.ID)
			}
		}

		if int64(len(videos)) < int64(size) || page*int64(size) >= total {
			break
		}
		page++
	}
}

// UploadCover 上传视频封面
func (s *VideoService) UploadCover(ctx context.Context, videoID int64, coverData []byte, contentType string) (string, error) {
	// 1. 验证封面数据
	if !s.isValidCoverType(contentType) {
		return "", fmt.Errorf("不支持的封面类型: %s", contentType)
	}

	// 2. 检查视频是否存在
	video, err := s.db.GetVideoByID(ctx, videoID)
	if err != nil {
		return "", fmt.Errorf("获取视频失败: %w", err)
	}

	// 3. 生成封面文件名
	ext := ".jpg"
	switch contentType {
	case "image/jpeg":
		ext = ".jpg"
	case "image/png":
		ext = ".png"
	case "image/gif":
		ext = ".gif"
	}

	timestamp := time.Now().Unix()
	coverFilename := fmt.Sprintf("%d_%d%s", videoID, timestamp, ext)
	coverPath := filepath.Join(config.Upload.Video.CoverDir, coverFilename)

	// 4. 确保封面目录存在
	if err := os.MkdirAll(config.Upload.Video.CoverDir, constants.DirPermission); err != nil {
		return "", fmt.Errorf("创建封面目录失败: %w", err)
	}

	// 5. 保存封面文件
	if err := os.WriteFile(coverPath, coverData, constants.FilePermission); err != nil {
		return "", fmt.Errorf("保存封面文件失败: %w", err)
	}

	// 6. 更新视频记录
	coverURL := fmt.Sprintf("%s/covers/%s", config.Upload.Video.BaseURL, coverFilename)
	video.CoverURL = coverURL

	if err := s.db.UpdateVideo(ctx, video); err != nil {
		// 如果更新数据库失败，删除已保存的封面文件
		_ = os.Remove(coverPath)
		return "", fmt.Errorf("更新视频封面信息失败: %w", err)
	}

	return coverURL, nil
}

// isValidCoverType 验证封面类型
func (s *VideoService) isValidCoverType(contentType string) bool {
	validTypes := map[string]bool{
		"image/jpeg": true,
		"image/png":  true,
		"image/gif":  true,
	}
	return validTypes[contentType]
}
