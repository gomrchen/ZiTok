package admin

import (
	"context"
	"io"
	"os"
	"path/filepath"
	"strconv"
	"time"

	"github.com/cloudwego/hertz/pkg/app"
	"github.com/yxrxy/videoHub/app/gateway/commerce"
	"github.com/yxrxy/videoHub/app/gateway/drama"
	"github.com/yxrxy/videoHub/app/gateway/pack"
	"github.com/yxrxy/videoHub/pkg/errno"
	"github.com/yxrxy/videoHub/pkg/jwt"
)

func Login(ctx context.Context, c *app.RequestContext) {
	var body struct {
		Username string `json:"username"`
		Password string `json:"password"`
	}
	if err := c.BindAndValidate(&body); err != nil {
		pack.RespError(c, errno.ParamVerifyError.WithError(err))
		return
	}
	u, err := commerce.AdminLogin(body.Username, body.Password)
	if err != nil {
		pack.RespError(c, errno.NewErrNo(errno.AuthInvalidCode, err.Error()))
		return
	}
	token, err := jwt.GenerateToken(u.ID)
	if err != nil {
		pack.RespError(c, err)
		return
	}
	pack.RespData(c, map[string]any{"token": token, "admin": u})
}

func ListDramas(ctx context.Context, c *app.RequestContext) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	size, _ := strconv.Atoi(c.DefaultQuery("size", "20"))
	statusQ := c.Query("status")
	var status *int8
	if statusQ == "" || statusQ == "all" {
		status = &drama.StatusAll
	} else {
		v, _ := strconv.Atoi(statusQ)
		s := int8(v)
		status = &s
	}
	list, total, err := drama.ListDramas(page, size, c.Query("category"), status)
	if err != nil {
		pack.RespError(c, err)
		return
	}
	pack.RespData(c, map[string]any{"list": list, "total": total})
}

func CreateDrama(ctx context.Context, c *app.RequestContext) {
	var d drama.Drama
	if err := c.BindAndValidate(&d); err != nil {
		pack.RespError(c, errno.ParamVerifyError.WithError(err))
		return
	}
	if d.Status == 0 {
		d.Status = 1
	}
	if d.FreeEpisodeCount == 0 {
		d.FreeEpisodeCount = 3
	}
	if err := drama.CreateDrama(&d); err != nil {
		pack.RespError(c, err)
		return
	}
	pack.RespData(c, d)
}

func UpdateDrama(ctx context.Context, c *app.RequestContext) {
	id, _ := strconv.ParseInt(c.Param("id"), 10, 64)
	var d drama.Drama
	if err := c.BindAndValidate(&d); err != nil {
		pack.RespError(c, errno.ParamVerifyError.WithError(err))
		return
	}
	d.ID = id
	if err := drama.UpdateDrama(&d); err != nil {
		pack.RespError(c, err)
		return
	}
	pack.RespData(c, d)
}

func OfflineDrama(ctx context.Context, c *app.RequestContext) {
	id, _ := strconv.ParseInt(c.Param("id"), 10, 64)
	if err := drama.SoftDeleteDrama(id); err != nil {
		pack.RespError(c, err)
		return
	}
	pack.RespSuccess(c)
}

func ListEpisodes(ctx context.Context, c *app.RequestContext) {
	id, _ := strconv.ParseInt(c.Param("id"), 10, 64)
	eps, err := drama.ListEpisodes(id)
	if err != nil {
		pack.RespError(c, err)
		return
	}
	pack.RespData(c, map[string]any{"list": eps})
}

func CreateEpisode(ctx context.Context, c *app.RequestContext) {
	dramaID, _ := strconv.ParseInt(c.Param("id"), 10, 64)
	var ep drama.Episode
	if err := c.BindAndValidate(&ep); err != nil {
		pack.RespError(c, errno.ParamVerifyError.WithError(err))
		return
	}
	ep.DramaID = dramaID
	if ep.UnlockPrice == 0 {
		ep.UnlockPrice = 10
	}
	if err := drama.CreateEpisode(&ep); err != nil {
		pack.RespError(c, err)
		return
	}
	pack.RespData(c, ep)
}

func UpdateEpisode(ctx context.Context, c *app.RequestContext) {
	epID, _ := strconv.ParseInt(c.Param("episode_id"), 10, 64)
	var ep drama.Episode
	if err := c.BindAndValidate(&ep); err != nil {
		pack.RespError(c, errno.ParamVerifyError.WithError(err))
		return
	}
	ep.ID = epID
	if err := drama.UpdateEpisode(&ep); err != nil {
		pack.RespError(c, err)
		return
	}
	pack.RespData(c, ep)
}

func UploadEpisodeVideo(ctx context.Context, c *app.RequestContext) {
	dramaID, _ := strconv.ParseInt(c.Param("id"), 10, 64)
	fileHeader, err := c.FormFile("video")
	if err != nil {
		pack.RespError(c, errno.ParamVerifyError.WithError(err))
		return
	}
	epNo, _ := strconv.Atoi(c.PostForm("episode_no"))
	title := c.PostForm("title")
	isFree := c.PostForm("is_free") == "1" || c.PostForm("is_free") == "true"
	price, _ := strconv.Atoi(c.PostForm("unlock_price"))
	if price <= 0 {
		price = 10
	}
	if epNo <= 0 {
		eps, _ := drama.ListEpisodes(dramaID)
		epNo = len(eps) + 1
	}
	if title == "" {
		title = "第" + strconv.Itoa(epNo) + "集"
	}

	dir := "src/storage/videos"
	_ = os.MkdirAll(dir, 0o755)
	name := strconv.FormatInt(time.Now().UnixNano(), 10) + filepath.Ext(fileHeader.Filename)
	dst := filepath.Join(dir, name)
	src, err := fileHeader.Open()
	if err != nil {
		pack.RespError(c, err)
		return
	}
	defer src.Close()
	out, err := os.Create(dst)
	if err != nil {
		pack.RespError(c, err)
		return
	}
	defer out.Close()
	if _, err := io.Copy(out, src); err != nil {
		pack.RespError(c, err)
		return
	}
	// StaticFS Root=src/storage → 公开路径 /videos/<file>
	// App/iOS 模拟器需绝对地址才能播
	url := "http://127.0.0.1:28880/videos/" + name
	ep := &drama.Episode{
		DramaID:     dramaID,
		EpisodeNo:   epNo,
		Title:       title,
		VideoURL:    url,
		CoverURL:    "",
		IsFree:      isFree,
		UnlockPrice: price,
		Duration:    60,
	}
	if err := drama.CreateEpisode(ep); err != nil {
		pack.RespError(c, err)
		return
	}
	pack.RespData(c, ep)
}

func AdjustWallet(ctx context.Context, c *app.RequestContext) {
	var body struct {
		UserID int64  `json:"user_id"`
		Delta  int    `json:"delta"`
		Reason string `json:"reason"`
	}
	if err := c.BindAndValidate(&body); err != nil || body.UserID <= 0 {
		pack.RespError(c, errno.ParamVerifyError)
		return
	}
	if body.Reason == "" {
		body.Reason = "admin"
	}
	bal, err := commerce.ChangeBalance(body.UserID, body.Delta, body.Reason, "admin")
	if err != nil {
		pack.RespError(c, errno.NewErrNo(errno.InternalServiceErrorCode, err.Error()))
		return
	}
	pack.RespData(c, map[string]any{"balance": bal})
}

func Stats(ctx context.Context, c *app.RequestContext) {
	db, err := drama.DB()
	if err != nil {
		pack.RespError(c, err)
		return
	}
	var dramaCount, episodeCount, unlockCount int64
	var playSum int64
	db.Model(&drama.Drama{}).Where("deleted_at IS NULL").Count(&dramaCount)
	db.Model(&drama.Episode{}).Where("deleted_at IS NULL").Count(&episodeCount)
	db.Model(&commerce.UnlockPurchase{}).Count(&unlockCount)
	db.Model(&drama.Drama{}).Select("COALESCE(SUM(play_count),0)").Scan(&playSum)
	pack.RespData(c, map[string]any{
		"drama_count":   dramaCount,
		"episode_count": episodeCount,
		"unlock_count":  unlockCount,
		"play_sum":      playSum,
	})
}
