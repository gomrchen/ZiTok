package commerce

import core "github.com/yxrxy/videoHub/app/commerce"

type (
	Wallet         = core.Wallet
	CoinLedger     = core.CoinLedger
	UnlockPurchase = core.UnlockPurchase
	AdminUser      = core.AdminUser
)

var (
	DB               = core.DB
	EnsureWallet     = core.EnsureWallet
	GetBalance       = core.GetBalance
	ChangeBalance    = core.ChangeBalance
	ListLedger       = core.ListLedger
	HasUnlock        = core.HasUnlock
	UnlockEpisode    = core.UnlockEpisode
	UnlockDrama      = core.UnlockDrama
	AdUnlockEpisode  = core.AdUnlockEpisode
	AdReward         = core.AdReward
	MockTopup        = core.MockTopup
	EnsureAdminSeed  = core.EnsureAdminSeed
	AdminLogin       = core.AdminLogin
	Topup            = core.Topup
)
