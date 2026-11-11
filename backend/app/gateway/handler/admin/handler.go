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
	pkgcontext "github.com/yxrxy/videoHub/pkg/base/context"
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
	} else if statusQ == "deleted" {
		s := int8(-2)
		status = &s
	} else {
		v, _ := strconv.Atoi(statusQ)
		s := int8(v)
		status = &s
	}
	list, total, err := drama.ListDramasFilteredSort(page, size, c.Query("category"), c.Query("q"), status, c.Query("sort"))
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
	if err := drama.SetDramaStatus(id, 2); err != nil {
		pack.RespError(c, err)
		return
	}
	pack.RespSuccess(c)
}

func OnlineDrama(ctx context.Context, c *app.RequestContext) {
	id, _ := strconv.ParseInt(c.Param("id"), 10, 64)
	if err := drama.SetDramaStatus(id, 1); err != nil {
		pack.RespError(c, err)
		return
	}
	pack.RespSuccess(c)
}

func DeleteDrama(ctx context.Context, c *app.RequestContext) {
	id, _ := strconv.ParseInt(c.Param("id"), 10, 64)
	if err := drama.SoftDeleteDrama(id); err != nil {
		pack.RespError(c, errno.NewErrNo(errno.InternalServiceErrorCode, err.Error()))
		return
	}
	pack.RespSuccess(c)
}

func RestoreDrama(ctx context.Context, c *app.RequestContext) {
	id, _ := strconv.ParseInt(c.Param("id"), 10, 64)
	if err := drama.RestoreDrama(id); err != nil {
		pack.RespError(c, errno.NewErrNo(errno.InternalServiceErrorCode, err.Error()))
		return
	}
	pack.RespSuccess(c)
}

func BatchDramaStatus(ctx context.Context, c *app.RequestContext) {
	var body struct {
		IDs    []int64 `json:"ids"`
		Status int8    `json:"status"`
	}
	if err := c.BindAndValidate(&body); err != nil || len(body.IDs) == 0 || (body.Status != 1 && body.Status != 2) {
		pack.RespError(c, errno.ParamVerifyError)
		return
	}
	n, err := drama.BatchSetDramaStatus(body.IDs, body.Status)
	if err != nil {
		pack.RespError(c, errno.NewErrNo(errno.InternalServiceErrorCode, err.Error()))
		return
	}
	pack.RespData(c, map[string]any{"updated": n})
}

func ListCategories(ctx context.Context, c *app.RequestContext) {
	list, err := drama.ListCategories()
	if err != nil {
		pack.RespError(c, errno.NewErrNo(errno.InternalServiceErrorCode, err.Error()))
		return
	}
	stats, _ := drama.ListCategoryStats()
	pack.RespData(c, map[string]any{"list": list, "stats": stats})
}

func CreateCategory(ctx context.Context, c *app.RequestContext) {
	var body struct {
		Name      string `json:"name"`
		SortOrder int    `json:"sort_order"`
	}
	if err := c.BindAndValidate(&body); err != nil || body.Name == "" {
		pack.RespError(c, errno.ParamVerifyError)
		return
	}
	if err := drama.CreateCategory(body.Name, body.SortOrder); err != nil {
		pack.RespError(c, errno.NewErrNo(errno.InternalServiceErrorCode, err.Error()))
		return
	}
	pack.RespData(c, map[string]any{"name": body.Name})
}

func RenameCategory(ctx context.Context, c *app.RequestContext) {
	var body struct {
		From string `json:"from"`
		To   string `json:"to"`
	}
	if err := c.BindAndValidate(&body); err != nil || body.From == "" || body.To == "" {
		pack.RespError(c, errno.ParamVerifyError)
		return
	}
	n, err := drama.RenameCategory(body.From, body.To)
	if err != nil {
		pack.RespError(c, errno.NewErrNo(errno.InternalServiceErrorCode, err.Error()))
		return
	}
	pack.RespData(c, map[string]any{"updated": n})
}

func DeleteCategory(ctx context.Context, c *app.RequestContext) {
	var body struct {
		Name   string `json:"name"`
		MoveTo string `json:"move_to"`
	}
	if err := c.BindAndValidate(&body); err != nil || body.Name == "" {
		// 兼容 query / path
		body.Name = c.Query("name")
		if body.Name == "" {
			body.Name = c.Param("name")
		}
		body.MoveTo = c.Query("move_to")
	}
	if body.Name == "" {
		pack.RespError(c, errno.ParamVerifyError)
		return
	}
	n, err := drama.DeleteCategory(body.Name, body.MoveTo)
	if err != nil {
		pack.RespError(c, errno.NewErrNo(errno.InternalServiceErrorCode, err.Error()))
		return
	}
	pack.RespData(c, map[string]any{"moved": n})
}

func BatchRestoreDramas(ctx context.Context, c *app.RequestContext) {
	var body struct {
		IDs []int64 `json:"ids"`
	}
	if err := c.BindAndValidate(&body); err != nil || len(body.IDs) == 0 {
		pack.RespError(c, errno.ParamVerifyError)
		return
	}
	n, err := drama.BatchRestoreDramas(body.IDs)
	if err != nil {
		pack.RespError(c, errno.NewErrNo(errno.InternalServiceErrorCode, err.Error()))
		return
	}
	pack.RespData(c, map[string]any{"updated": n})
}

func HardDeleteDrama(ctx context.Context, c *app.RequestContext) {
	id, _ := strconv.ParseInt(c.Param("id"), 10, 64)
	if id <= 0 {
		pack.RespError(c, errno.ParamVerifyError)
		return
	}
	if err := drama.HardDeleteDrama(id); err != nil {
		pack.RespError(c, errno.NewErrNo(errno.InternalServiceErrorCode, err.Error()))
		return
	}
	pack.RespSuccess(c)
}

func BatchHardDeleteDramas(ctx context.Context, c *app.RequestContext) {
	var body struct {
		IDs []int64 `json:"ids"`
	}
	if err := c.BindAndValidate(&body); err != nil || len(body.IDs) == 0 {
		pack.RespError(c, errno.ParamVerifyError)
		return
	}
	n, err := drama.BatchHardDeleteDramas(body.IDs)
	if err != nil {
		pack.RespError(c, errno.NewErrNo(errno.InternalServiceErrorCode, err.Error()))
		return
	}
	pack.RespData(c, map[string]any{"deleted": n})
}

func ChangePassword(ctx context.Context, c *app.RequestContext) {
	adminID, err := pkgcontext.GetUserID(ctx)
	if err != nil || adminID <= 0 {
		pack.RespError(c, errno.NewErrNo(errno.AuthInvalidCode, "未登录"))
		return
	}
	var body struct {
		OldPassword string `json:"old_password"`
		NewPassword string `json:"new_password"`
	}
	if err := c.BindAndValidate(&body); err != nil {
		pack.RespError(c, errno.ParamVerifyError)
		return
	}
	if err := commerce.ChangeAdminPassword(adminID, body.OldPassword, body.NewPassword); err != nil {
		pack.RespError(c, errno.NewErrNo(errno.InternalServiceErrorCode, err.Error()))
		return
	}
	pack.RespSuccess(c)
}

func GetDramaDetail(ctx context.Context, c *app.RequestContext) {
	id, _ := strconv.ParseInt(c.Param("id"), 10, 64)
	d, err := drama.GetDrama(id)
	if err != nil {
		pack.RespError(c, errno.NewErrNo(errno.InternalServiceErrorCode, err.Error()))
		return
	}
	eps, _ := drama.ListEpisodes(id)
	st, _ := drama.GetDramaOpsStat(id)
	epStats, _ := drama.ListEpisodeOpsStats(id)
	pack.RespData(c, map[string]any{"drama": d, "episodes": eps, "stats": st, "episode_stats": epStats})
}

func GetDramaStats(ctx context.Context, c *app.RequestContext) {
	id, _ := strconv.ParseInt(c.Param("id"), 10, 64)
	st, err := drama.GetDramaOpsStat(id)
	if err != nil {
		pack.RespError(c, errno.NewErrNo(errno.InternalServiceErrorCode, err.Error()))
		return
	}
	pack.RespData(c, st)
}

func SetEpisodeNo(ctx context.Context, c *app.RequestContext) {
	epID, _ := strconv.ParseInt(c.Param("episode_id"), 10, 64)
	var body struct {
		EpisodeNo int `json:"episode_no"`
	}
	if err := c.BindAndValidate(&body); err != nil || epID <= 0 || body.EpisodeNo <= 0 {
		pack.RespError(c, errno.ParamVerifyError)
		return
	}
	if err := drama.SetEpisodeNo(epID, body.EpisodeNo); err != nil {
		pack.RespError(c, errno.NewErrNo(errno.InternalServiceErrorCode, err.Error()))
		return
	}
	pack.RespSuccess(c)
}

func GrantUnlock(ctx context.Context, c *app.RequestContext) {
	var body struct {
		UserID     int64 `json:"user_id"`
		DramaID    int64 `json:"drama_id"`
		EpisodeID  int64 `json:"episode_id"`
		UnlockType int8  `json:"unlock_type"`
	}
	if err := c.BindAndValidate(&body); err != nil || body.UserID <= 0 || body.DramaID <= 0 {
		pack.RespError(c, errno.ParamVerifyError)
		return
	}
	if err := commerce.GrantUnlock(body.UserID, body.DramaID, body.EpisodeID, body.UnlockType); err != nil {
		pack.RespError(c, errno.NewErrNo(errno.InternalServiceErrorCode, err.Error()))
		return
	}
	pack.RespSuccess(c)
}

func RevokeUnlock(ctx context.Context, c *app.RequestContext) {
	id, _ := strconv.ParseInt(c.Param("id"), 10, 64)
	refund := c.Query("refund") == "1" || c.Query("refund") == "true"
	var body struct {
		Refund bool `json:"refund"`
	}
	_ = c.BindAndValidate(&body)
	if body.Refund {
		refund = true
	}
	if id <= 0 {
		pack.RespError(c, errno.ParamVerifyError)
		return
	}
	if err := commerce.RevokeUnlock(id, refund); err != nil {
		pack.RespError(c, errno.NewErrNo(errno.InternalServiceErrorCode, err.Error()))
		return
	}
	pack.RespSuccess(c)
}

func ListUsers(ctx context.Context, c *app.RequestContext) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	size, _ := strconv.Atoi(c.DefaultQuery("size", "20"))
	list, total, err := commerce.ListUsersSorted(c.Query("q"), page, size, c.Query("sort"))
	if err != nil {
		pack.RespError(c, errno.NewErrNo(errno.InternalServiceErrorCode, err.Error()))
		return
	}
	pack.RespData(c, map[string]any{"list": list, "total": total})
}

func DeleteEpisode(ctx context.Context, c *app.RequestContext) {
	epID, _ := strconv.ParseInt(c.Param("episode_id"), 10, 64)
	if err := drama.SoftDeleteEpisode(epID); err != nil {
		pack.RespError(c, errno.NewErrNo(errno.InternalServiceErrorCode, err.Error()))
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
	// 公开路径 /videos/<file>（Range handler）
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

func GetWallet(ctx context.Context, c *app.RequestContext) {
	uid, _ := strconv.ParseInt(c.Param("user_id"), 10, 64)
	if uid <= 0 {
		pack.RespError(c, errno.ParamVerifyError)
		return
	}
	bal, err := commerce.GetBalance(uid)
	if err != nil {
		pack.RespError(c, errno.NewErrNo(errno.InternalServiceErrorCode, err.Error()))
		return
	}
	ledger, _ := commerce.ListLedger(uid, 30)
	pack.RespData(c, map[string]any{"user_id": uid, "balance": bal, "ledger": ledger})
}

func ListLedger(ctx context.Context, c *app.RequestContext) {
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	uid, _ := strconv.ParseInt(c.Query("user_id"), 10, 64)
	reason := c.Query("reason")
	list, err := commerce.ListLedgerFiltered(uid, reason, limit)
	if err != nil {
		pack.RespError(c, errno.NewErrNo(errno.InternalServiceErrorCode, err.Error()))
		return
	}
	pack.RespData(c, map[string]any{"list": list})
}

func ListUnlocks(ctx context.Context, c *app.RequestContext) {
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	uid, _ := strconv.ParseInt(c.Query("user_id"), 10, 64)
	dramaID, _ := strconv.ParseInt(c.Query("drama_id"), 10, 64)
	ut, _ := strconv.Atoi(c.Query("unlock_type"))
	expiredOnly := c.Query("expired_only") == "1" || c.Query("expired_only") == "true"
	list, err := commerce.ListUnlocksEnriched(uid, dramaID, int8(ut), limit, expiredOnly)
	if err != nil {
		pack.RespError(c, errno.NewErrNo(errno.InternalServiceErrorCode, err.Error()))
		return
	}
	pack.RespData(c, map[string]any{"list": list})
}

func SearchUsers(ctx context.Context, c *app.RequestContext) {
	list, err := commerce.SearchUsers(c.Query("q"), 30)
	if err != nil {
		pack.RespError(c, errno.NewErrNo(errno.InternalServiceErrorCode, err.Error()))
		return
	}
	pack.RespData(c, map[string]any{"list": list})
}

func GetUserDetail(ctx context.Context, c *app.RequestContext) {
	uid, _ := strconv.ParseInt(c.Param("user_id"), 10, 64)
	if uid <= 0 {
		pack.RespError(c, errno.ParamVerifyError)
		return
	}
	bal, err := commerce.GetBalance(uid)
	if err != nil {
		pack.RespError(c, errno.NewErrNo(errno.InternalServiceErrorCode, err.Error()))
		return
	}
	ledger, _ := commerce.ListLedger(uid, 20)
	unlocks, _ := commerce.ListUnlocksEnriched(uid, 0, 0, 20, false)
	watching, _ := drama.ListWatchingByUser(uid, 20)
	favs, _ := drama.ListFavorites(uid)
	summary, _ := commerce.GetUserCommerceSummary(uid)
	pack.RespData(c, map[string]any{
		"user_id":     uid,
		"balance":     bal,
		"ledger":      ledger,
		"unlocks":     unlocks,
		"watching":    watching,
		"favorites":   favs,
		"fav_count":   len(favs),
		"watch_count": len(watching),
		"summary":     summary,
	})
}

func AdminTopup(ctx context.Context, c *app.RequestContext) {
	var body struct {
		UserID int64 `json:"user_id"`
		Amount int   `json:"amount"`
	}
	if err := c.BindAndValidate(&body); err != nil || body.UserID <= 0 {
		pack.RespError(c, errno.ParamVerifyError)
		return
	}
	bal, err := commerce.MockTopup(body.UserID, body.Amount)
	if err != nil {
		pack.RespError(c, errno.NewErrNo(errno.InternalServiceErrorCode, err.Error()))
		return
	}
	pack.RespData(c, map[string]any{"balance": bal})
}

func ListTopups(ctx context.Context, c *app.RequestContext) {
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "30"))
	uid, _ := strconv.ParseInt(c.Query("user_id"), 10, 64)
	list, err := commerce.ListTopupsFiltered(uid, limit)
	if err != nil {
		pack.RespError(c, errno.NewErrNo(errno.InternalServiceErrorCode, err.Error()))
		return
	}
	pack.RespData(c, map[string]any{"list": list})
}

func ListTopDramas(ctx context.Context, c *app.RequestContext) {
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "10"))
	list, err := drama.ListTopDramasBy(c.DefaultQuery("sort", "play"), limit)
	if err != nil {
		pack.RespError(c, errno.NewErrNo(errno.InternalServiceErrorCode, err.Error()))
		return
	}
	pack.RespData(c, map[string]any{"list": list})
}

func BatchEpisodePricing(ctx context.Context, c *app.RequestContext) {
	dramaID, _ := strconv.ParseInt(c.Param("id"), 10, 64)
	var body struct {
		FreeCount   int `json:"free_count"`
		UnlockPrice int `json:"unlock_price"`
	}
	if err := c.BindAndValidate(&body); err != nil || dramaID <= 0 {
		pack.RespError(c, errno.ParamVerifyError)
		return
	}
	n, err := drama.BatchSetEpisodePricing(dramaID, body.FreeCount, body.UnlockPrice)
	if err != nil {
		pack.RespError(c, errno.NewErrNo(errno.InternalServiceErrorCode, err.Error()))
		return
	}
	pack.RespData(c, map[string]any{"updated": n})
}

func UploadCover(ctx context.Context, c *app.RequestContext) {
	fileHeader, err := c.FormFile("cover")
	if err != nil {
		pack.RespError(c, errno.ParamVerifyError.WithError(err))
		return
	}
	dir := "src/storage/covers"
	_ = os.MkdirAll(dir, 0o755)
	ext := filepath.Ext(fileHeader.Filename)
	if ext == "" {
		ext = ".jpg"
	}
	name := "cover_" + strconv.FormatInt(time.Now().UnixNano(), 10) + ext
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
	url := "/covers/" + name
	dramaID, _ := strconv.ParseInt(c.PostForm("drama_id"), 10, 64)
	if dramaID > 0 {
		_ = drama.UpdateDrama(&drama.Drama{ID: dramaID, CoverURL: url})
	}
	pack.RespData(c, map[string]any{"cover_url": url})
}

func Stats(ctx context.Context, c *app.RequestContext) {
	db, err := drama.DB()
	if err != nil {
		pack.RespError(c, err)
		return
	}
	var dramaCount, onlineCount, episodeCount, unlockCount, userCount int64
	var playSum int64
	var coinSum int64
	db.Model(&drama.Drama{}).Where("deleted_at IS NULL").Count(&dramaCount)
	db.Model(&drama.Drama{}).Where("deleted_at IS NULL AND status = 1").Count(&onlineCount)
	db.Model(&drama.Episode{}).Where("deleted_at IS NULL").Count(&episodeCount)
	db.Model(&commerce.UnlockPurchase{}).Count(&unlockCount)
	db.Model(&drama.Drama{}).Where("deleted_at IS NULL").Select("COALESCE(SUM(play_count),0)").Scan(&playSum)
	db.Table("users").Where("deleted_at IS NULL").Count(&userCount)
	db.Table("wallet").Select("COALESCE(SUM(balance),0)").Scan(&coinSum)
	top, _ := drama.ListTopDramas(5)
	rev, _ := commerce.GetRevenueSnapshot()
	typeStats, _ := commerce.ListUnlockTypeStats()
	dailyRev, _ := commerce.ListDailyRevenue(7)
	dailySignups, _ := commerce.ListDailySignups(7)
	dailyTopups, _ := commerce.ListDailyTopups(7)
	recentUnlocks, _ := commerce.ListUnlocksEnriched(0, 0, 0, 10, false)
	recentTopups, _ := commerce.ListTopupsFiltered(0, 10)
	out := map[string]any{
		"drama_count":     dramaCount,
		"online_count":    onlineCount,
		"episode_count":   episodeCount,
		"unlock_count":    unlockCount,
		"play_sum":        playSum,
		"user_count":      userCount,
		"coin_sum":        coinSum,
		"top_dramas":      top,
		"unlock_types":    typeStats,
		"daily_revenue":   dailyRev,
		"daily_signups":   dailySignups,
		"daily_topups":    dailyTopups,
		"recent_unlocks":  recentUnlocks,
		"recent_topups":   recentTopups,
	}
	if rev != nil {
		out["unlock_revenue"] = rev.UnlockRevenue
		out["today_unlocks"] = rev.TodayUnlocks
		out["today_revenue"] = rev.TodayRevenue
		out["today_topup_amt"] = rev.TodayTopupAmt
		out["today_topup_cnt"] = rev.TodayTopupCnt
		out["ad_unlock_count"] = rev.AdUnlockCount
	}
	pack.RespData(c, out)
}
