package commerce

import core "github.com/yxrxy/videoHub/app/commerce"

type (
	Wallet          = core.Wallet
	CoinLedger      = core.CoinLedger
	UnlockPurchase  = core.UnlockPurchase
	AdminUser       = core.AdminUser
	UserBrief       = core.UserBrief
	RevenueSnapshot   = core.RevenueSnapshot
	UnlockTypeStat    = core.UnlockTypeStat
	DailyRevenuePoint   = core.DailyRevenuePoint
	UnlockView          = core.UnlockView
	UserCommerceSummary = core.UserCommerceSummary
)

var (
	DB                   = core.DB
	EnsureWallet         = core.EnsureWallet
	GetBalance           = core.GetBalance
	ChangeBalance        = core.ChangeBalance
	ListLedger           = core.ListLedger
	ListRecentLedger     = core.ListRecentLedger
	ListRecentUnlocks    = core.ListRecentUnlocks
	ListUnlocksFiltered  = core.ListUnlocksFiltered
	ListUnlocksQuery     = core.ListUnlocksQuery
	ListUnlocksEnriched  = core.ListUnlocksEnriched
	ListTopups           = core.ListTopups
	ListTopupsFiltered   = core.ListTopupsFiltered
	ListLedgerFiltered   = core.ListLedgerFiltered
	SearchUsers          = core.SearchUsers
	ListUsers            = core.ListUsers
	ListUsersSorted      = core.ListUsersSorted
	HasUnlock            = core.HasUnlock
	UnlockEpisode        = core.UnlockEpisode
	UnlockDrama          = core.UnlockDrama
	AdUnlockEpisode      = core.AdUnlockEpisode
	AdReward             = core.AdReward
	MockTopup            = core.MockTopup
	GrantUnlock          = core.GrantUnlock
	RevokeUnlock         = core.RevokeUnlock
	GetRevenueSnapshot   = core.GetRevenueSnapshot
	ListUnlockTypeStats  = core.ListUnlockTypeStats
	ListDailyRevenue     = core.ListDailyRevenue
	ListDailySignups     = core.ListDailySignups
	ListDailyTopups      = core.ListDailyTopups
	GetUserCommerceSummary = core.GetUserCommerceSummary
	ChangeAdminPassword  = core.ChangeAdminPassword
	EnsureAdminSeed      = core.EnsureAdminSeed
	AdminLogin           = core.AdminLogin
	Topup                = core.Topup
)
