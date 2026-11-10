package commerce

import (
	"fmt"
	"time"
)

// PaymentProvider 支付渠道适配层
type PaymentProvider interface {
	Name() string
	// Charge 校验凭证并发放金币；Mock 直接成功
	Charge(userID int64, amount int, receipt string) (orderID string, err error)
}

type MockProvider struct{}

func (MockProvider) Name() string { return "mock" }

func (MockProvider) Charge(userID int64, amount int, receipt string) (string, error) {
	if amount <= 0 {
		return "", fmt.Errorf("invalid amount")
	}
	return fmt.Sprintf("mock_%d_%d", userID, time.Now().UnixNano()), nil
}

// WechatProvider / AppleProvider 预留接口，一期返回未实现
type WechatProvider struct{}

func (WechatProvider) Name() string { return "wechat" }

func (WechatProvider) Charge(userID int64, amount int, receipt string) (string, error) {
	return "", fmt.Errorf("wechat pay not configured")
}

type AppleProvider struct{}

func (AppleProvider) Name() string { return "apple" }

func (AppleProvider) Charge(userID int64, amount int, receipt string) (string, error) {
	return "", fmt.Errorf("apple iap not configured")
}

func GetProvider(name string) PaymentProvider {
	switch name {
	case "wechat":
		return WechatProvider{}
	case "apple":
		return AppleProvider{}
	default:
		return MockProvider{}
	}
}

// Topup 通过支付适配层充值并入账
func Topup(userID int64, amount int, provider, receipt string) (balance int, orderID string, usedProvider string, err error) {
	p := GetProvider(provider)
	usedProvider = p.Name()
	orderID, err = p.Charge(userID, amount, receipt)
	if err != nil {
		return 0, "", usedProvider, err
	}
	balance, err = ChangeBalance(userID, amount, "topup", fmt.Sprintf("%s:%s", usedProvider, orderID))
	return balance, orderID, usedProvider, err
}
