package handler

import (
	"context"
	"time"

	"github.com/yxrxy/videoHub/app/commerce"
	"github.com/yxrxy/videoHub/app/drama"
	base "github.com/yxrxy/videoHub/pkg/base"
	kcommerce "github.com/yxrxy/videoHub/kitex_gen/commerce"
)

type CommerceServiceImpl struct{}

func New() *CommerceServiceImpl { return &CommerceServiceImpl{} }

func (s *CommerceServiceImpl) GetWallet(ctx context.Context, req *kcommerce.GetWalletRequest) (*kcommerce.GetWalletResponse, error) {
	resp := kcommerce.NewGetWalletResponse()
	w, err := commerce.EnsureWallet(req.UserId)
	if err != nil {
		return nil, err
	}
	resp.Base = base.BuildBaseResp(nil)
	resp.Wallet = &kcommerce.WalletInfo{UserId: w.UserID, Balance: int32(w.Balance)}
	return resp, nil
}

func (s *CommerceServiceImpl) ListLedger(ctx context.Context, req *kcommerce.ListLedgerRequest) (*kcommerce.ListLedgerResponse, error) {
	resp := kcommerce.NewListLedgerResponse()
	list, err := commerce.ListLedger(req.UserId, int(req.GetLimit()))
	if err != nil {
		return nil, err
	}
	resp.Base = base.BuildBaseResp(nil)
	resp.List = make([]*kcommerce.LedgerItem, 0, len(list))
	for _, x := range list {
		resp.List = append(resp.List, &kcommerce.LedgerItem{
			Id:           x.ID,
			UserId:       x.UserID,
			ChangeAmount: int32(x.ChangeAmount),
			BalanceAfter: int32(x.BalanceAfter),
			Reason:       x.Reason,
			RefId:        x.RefID,
			CreatedAt:    x.CreatedAt.Format(time.RFC3339),
		})
	}
	return resp, nil
}

func (s *CommerceServiceImpl) UnlockEpisode(ctx context.Context, req *kcommerce.UnlockEpisodeRequest) (*kcommerce.UnlockEpisodeResponse, error) {
	resp := kcommerce.NewUnlockEpisodeResponse()
	ep, err := drama.GetEpisode(req.EpisodeId)
	if err != nil {
		return nil, err
	}
	d, err := drama.GetDrama(ep.DramaID)
	if err != nil {
		return nil, err
	}
	bal, err := commerce.UnlockEpisode(req.UserId, ep, d)
	if err != nil {
		return nil, err
	}
	resp.Base = base.BuildBaseResp(nil)
	resp.Balance = int32(bal)
	resp.Unlocked = true
	return resp, nil
}

func (s *CommerceServiceImpl) UnlockDrama(ctx context.Context, req *kcommerce.UnlockDramaRequest) (*kcommerce.UnlockDramaResponse, error) {
	resp := kcommerce.NewUnlockDramaResponse()
	d, err := drama.GetDrama(req.DramaId)
	if err != nil {
		return nil, err
	}
	bal, err := commerce.UnlockDrama(req.UserId, d)
	if err != nil {
		return nil, err
	}
	resp.Base = base.BuildBaseResp(nil)
	resp.Balance = int32(bal)
	resp.Unlocked = true
	return resp, nil
}

func (s *CommerceServiceImpl) AdUnlock(ctx context.Context, req *kcommerce.AdUnlockRequest) (*kcommerce.AdUnlockResponse, error) {
	resp := kcommerce.NewAdUnlockResponse()
	ep, err := drama.GetEpisode(req.EpisodeId)
	if err != nil {
		return nil, err
	}
	d, err := drama.GetDrama(ep.DramaID)
	if err != nil {
		return nil, err
	}
	if err := commerce.AdUnlockEpisode(req.UserId, ep, d); err != nil {
		return nil, err
	}
	resp.Base = base.BuildBaseResp(nil)
	resp.Unlocked = true
	resp.ExpireHours = 24
	return resp, nil
}

func (s *CommerceServiceImpl) AdReward(ctx context.Context, req *kcommerce.AdRewardRequest) (*kcommerce.AdRewardResponse, error) {
	resp := kcommerce.NewAdRewardResponse()
	bal, err := commerce.AdReward(req.UserId)
	if err != nil {
		return nil, err
	}
	resp.Base = base.BuildBaseResp(nil)
	resp.Balance = int32(bal)
	resp.Reward = 5
	return resp, nil
}

func (s *CommerceServiceImpl) Topup(ctx context.Context, req *kcommerce.TopupRequest) (*kcommerce.TopupResponse, error) {
	resp := kcommerce.NewTopupResponse()
	bal, orderID, provider, err := commerce.Topup(req.UserId, int(req.Amount), req.GetProvider(), req.GetReceipt())
	if err != nil {
		return nil, err
	}
	resp.Base = base.BuildBaseResp(nil)
	resp.Balance = int32(bal)
	resp.Provider = provider
	resp.OrderId = orderID
	return resp, nil
}

func (s *CommerceServiceImpl) AdjustWallet(ctx context.Context, req *kcommerce.AdjustWalletRequest) (*kcommerce.AdjustWalletResponse, error) {
	resp := kcommerce.NewAdjustWalletResponse()
	reason := req.GetReason()
	if reason == "" {
		reason = "admin"
	}
	bal, err := commerce.ChangeBalance(req.UserId, int(req.Delta), reason, "admin")
	if err != nil {
		return nil, err
	}
	resp.Base = base.BuildBaseResp(nil)
	resp.Balance = int32(bal)
	return resp, nil
}

func (s *CommerceServiceImpl) HasUnlock(ctx context.Context, req *kcommerce.HasUnlockRequest) (*kcommerce.HasUnlockResponse, error) {
	resp := kcommerce.NewHasUnlockResponse()
	resp.Base = base.BuildBaseResp(nil)
	resp.Unlocked = commerce.HasUnlock(req.UserId, req.DramaId, req.EpisodeId)
	return resp, nil
}

