package commerce

import (
	"context"
	"strconv"

	"github.com/cloudwego/hertz/pkg/app"
	"github.com/yxrxy/videoHub/app/gateway/commerce"
	"github.com/yxrxy/videoHub/app/gateway/pack"
	"github.com/yxrxy/videoHub/app/gateway/rpc"
	pkgcontext "github.com/yxrxy/videoHub/pkg/base/context"
	"github.com/yxrxy/videoHub/pkg/errno"
)

func requireUID(ctx context.Context, c *app.RequestContext) (int64, bool) {
	uid, err := pkgcontext.GetUserID(ctx)
	if err != nil || uid <= 0 {
		pack.RespError(c, errno.NewErrNo(errno.AuthInvalidCode, "未登录"))
		return 0, false
	}
	return uid, true
}

func GetWallet(ctx context.Context, c *app.RequestContext) {
	uid, ok := requireUID(ctx, c)
	if !ok {
		return
	}
	w, err := rpc.GetWalletRPC(ctx, uid)
	if err != nil {
		pack.RespError(c, err)
		return
	}
	pack.RespData(c, w)
}

func ListLedger(ctx context.Context, c *app.RequestContext) {
	uid, ok := requireUID(ctx, c)
	if !ok {
		return
	}
	list, err := rpc.ListLedgerRPC(ctx, uid)
	if err != nil {
		pack.RespError(c, err)
		return
	}
	pack.RespData(c, map[string]any{"list": list})
}

func UnlockEpisode(ctx context.Context, c *app.RequestContext) {
	uid, ok := requireUID(ctx, c)
	if !ok {
		return
	}
	var body struct {
		EpisodeID int64 `json:"episode_id"`
	}
	if err := c.BindAndValidate(&body); err != nil || body.EpisodeID <= 0 {
		pack.RespError(c, errno.ParamVerifyError)
		return
	}
	bal, err := rpc.UnlockEpisodeRPC(ctx, uid, body.EpisodeID)
	if err != nil {
		pack.RespError(c, errno.NewErrNo(errno.InternalServiceErrorCode, err.Error()))
		return
	}
	pack.RespData(c, map[string]any{"balance": bal, "unlocked": true})
}

func UnlockDrama(ctx context.Context, c *app.RequestContext) {
	uid, ok := requireUID(ctx, c)
	if !ok {
		return
	}
	var body struct {
		DramaID int64 `json:"drama_id"`
	}
	if err := c.BindAndValidate(&body); err != nil || body.DramaID <= 0 {
		pack.RespError(c, errno.ParamVerifyError)
		return
	}
	bal, err := rpc.UnlockDramaRPC(ctx, uid, body.DramaID)
	if err != nil {
		pack.RespError(c, errno.NewErrNo(errno.InternalServiceErrorCode, err.Error()))
		return
	}
	pack.RespData(c, map[string]any{"balance": bal, "unlocked": true})
}

func AdUnlock(ctx context.Context, c *app.RequestContext) {
	uid, ok := requireUID(ctx, c)
	if !ok {
		return
	}
	var body struct {
		EpisodeID int64 `json:"episode_id"`
	}
	if err := c.BindAndValidate(&body); err != nil || body.EpisodeID <= 0 {
		pack.RespError(c, errno.ParamVerifyError)
		return
	}
	if err := rpc.AdUnlockRPC(ctx, uid, body.EpisodeID); err != nil {
		pack.RespError(c, err)
		return
	}
	pack.RespData(c, map[string]any{"unlocked": true, "expire_hours": 24})
}

func AdReward(ctx context.Context, c *app.RequestContext) {
	uid, ok := requireUID(ctx, c)
	if !ok {
		return
	}
	bal, err := commerce.AdReward(uid)
	if err != nil {
		pack.RespError(c, err)
		return
	}
	pack.RespData(c, map[string]any{"balance": bal, "reward": 5})
}

func MockTopup(ctx context.Context, c *app.RequestContext) {
	uid, ok := requireUID(ctx, c)
	if !ok {
		return
	}
	amount, _ := strconv.Atoi(c.DefaultQuery("amount", "100"))
	var body struct {
		Amount   int    `json:"amount"`
		Provider string `json:"provider"`
		Receipt  string `json:"receipt"`
	}
	_ = c.BindAndValidate(&body)
	if body.Amount > 0 {
		amount = body.Amount
	}
	if amount <= 0 {
		amount = 100
	}
	provider := body.Provider
	if provider == "" {
		provider = "mock"
	}
	bal, orderID, used, err := rpc.TopupRPC(ctx, uid, int32(amount), provider, body.Receipt)
	if err != nil {
		pack.RespError(c, errno.NewErrNo(errno.InternalServiceErrorCode, err.Error()))
		return
	}
	pack.RespData(c, map[string]any{"balance": bal, "order_id": orderID, "provider": used})
}
