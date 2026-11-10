package rpc

import (
	"context"
	"log"

	local "github.com/yxrxy/videoHub/app/commerce"
	"github.com/yxrxy/videoHub/app/drama"
	"github.com/yxrxy/videoHub/kitex_gen/commerce"
	"github.com/yxrxy/videoHub/kitex_gen/commerce/commerceservice"
	"github.com/yxrxy/videoHub/pkg/base/client"
	"github.com/yxrxy/videoHub/pkg/errno"
)

var commerceClient commerceservice.Client
var commerceRPCReady bool

func InitCommerceRPC() {
	c, err := client.InitCommerceRPC()
	if err != nil {
		log.Printf("[gateway] Commerce RPC 不可用，使用本地领域降级: %v", err)
		commerceRPCReady = false
		return
	}
	commerceClient = *c
	commerceRPCReady = true
	log.Printf("[gateway] Commerce RPC ready")
}

func GetWalletRPC(ctx context.Context, userID int64) (*commerce.WalletInfo, error) {
	if commerceRPCReady {
		resp, err := commerceClient.GetWallet(ctx, &commerce.GetWalletRequest{UserId: userID})
		if err == nil && resp != nil && resp.Base != nil && resp.Base.Code == errno.SuccessCode {
			return resp.Wallet, nil
		}
		if err != nil {
			log.Printf("[gateway] GetWallet RPC fail, fallback: %v", err)
		}
	}
	w, err := local.EnsureWallet(userID)
	if err != nil {
		return nil, err
	}
	return &commerce.WalletInfo{UserId: w.UserID, Balance: int32(w.Balance)}, nil
}

func UnlockEpisodeRPC(ctx context.Context, userID, episodeID int64) (int32, error) {
	if commerceRPCReady {
		resp, err := commerceClient.UnlockEpisode(ctx, &commerce.UnlockEpisodeRequest{UserId: userID, EpisodeId: episodeID})
		if err == nil && resp != nil && resp.Base != nil && resp.Base.Code == errno.SuccessCode {
			return resp.Balance, nil
		}
		if err != nil {
			log.Printf("[gateway] UnlockEpisode RPC fail, fallback: %v", err)
		}
	}
	ep, err := drama.GetEpisode(episodeID)
	if err != nil {
		return 0, err
	}
	d, err := drama.GetDrama(ep.DramaID)
	if err != nil {
		return 0, err
	}
	bal, err := local.UnlockEpisode(userID, ep, d)
	return int32(bal), err
}

func UnlockDramaRPC(ctx context.Context, userID, dramaID int64) (int32, error) {
	if commerceRPCReady {
		resp, err := commerceClient.UnlockDrama(ctx, &commerce.UnlockDramaRequest{UserId: userID, DramaId: dramaID})
		if err == nil && resp != nil && resp.Base != nil && resp.Base.Code == errno.SuccessCode {
			return resp.Balance, nil
		}
		if err != nil {
			log.Printf("[gateway] UnlockDrama RPC fail, fallback: %v", err)
		}
	}
	d, err := drama.GetDrama(dramaID)
	if err != nil {
		return 0, err
	}
	bal, err := local.UnlockDrama(userID, d)
	return int32(bal), err
}

func AdUnlockRPC(ctx context.Context, userID, episodeID int64) error {
	if commerceRPCReady {
		resp, err := commerceClient.AdUnlock(ctx, &commerce.AdUnlockRequest{UserId: userID, EpisodeId: episodeID})
		if err == nil && resp != nil && resp.Base != nil && resp.Base.Code == errno.SuccessCode {
			return nil
		}
		if err != nil {
			log.Printf("[gateway] AdUnlock RPC fail, fallback: %v", err)
		}
	}
	ep, err := drama.GetEpisode(episodeID)
	if err != nil {
		return err
	}
	d, err := drama.GetDrama(ep.DramaID)
	if err != nil {
		return err
	}
	return local.AdUnlockEpisode(userID, ep, d)
}

func TopupRPC(ctx context.Context, userID int64, amount int32, provider, receipt string) (balance int32, orderID, used string, err error) {
	if commerceRPCReady {
		req := &commerce.TopupRequest{UserId: userID, Amount: amount}
		if provider != "" {
			req.Provider = &provider
		}
		if receipt != "" {
			req.Receipt = &receipt
		}
		resp, e := commerceClient.Topup(ctx, req)
		if e == nil && resp != nil && resp.Base != nil && resp.Base.Code == errno.SuccessCode {
			return resp.Balance, resp.OrderId, resp.Provider, nil
		}
		if e != nil {
			log.Printf("[gateway] Topup RPC fail, fallback: %v", e)
		}
	}
	bal, oid, used, err := local.Topup(userID, int(amount), provider, receipt)
	return int32(bal), oid, used, err
}

func ListLedgerRPC(ctx context.Context, userID int64) ([]*commerce.LedgerItem, error) {
	if commerceRPCReady {
		lim := int32(50)
		resp, err := commerceClient.ListLedger(ctx, &commerce.ListLedgerRequest{UserId: userID, Limit: &lim})
		if err == nil && resp != nil && resp.Base != nil && resp.Base.Code == errno.SuccessCode {
			return resp.List, nil
		}
		if err != nil {
			log.Printf("[gateway] ListLedger RPC fail, fallback: %v", err)
		}
	}
	list, err := local.ListLedger(userID, 50)
	if err != nil {
		return nil, err
	}
	out := make([]*commerce.LedgerItem, 0, len(list))
	for _, x := range list {
		out = append(out, &commerce.LedgerItem{
			Id: x.ID, UserId: x.UserID, ChangeAmount: int32(x.ChangeAmount),
			BalanceAfter: int32(x.BalanceAfter), Reason: x.Reason, RefId: x.RefID,
			CreatedAt: x.CreatedAt.Format("2006-01-02T15:04:05Z07:00"),
		})
	}
	return out, nil
}
