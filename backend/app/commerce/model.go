package commerce

import "time"

type Wallet struct {
	UserID    int64     `gorm:"column:user_id;primaryKey" json:"user_id"`
	Balance   int       `gorm:"column:balance" json:"balance"`
	UpdatedAt time.Time `gorm:"column:updated_at" json:"updated_at"`
}

func (Wallet) TableName() string { return "wallet" }

type CoinLedger struct {
	ID           int64     `gorm:"column:id;primaryKey" json:"id"`
	UserID       int64     `gorm:"column:user_id" json:"user_id"`
	ChangeAmount int       `gorm:"column:change_amount" json:"change_amount"`
	BalanceAfter int       `gorm:"column:balance_after" json:"balance_after"`
	Reason       string    `gorm:"column:reason" json:"reason"`
	RefID        string    `gorm:"column:ref_id" json:"ref_id"`
	CreatedAt    time.Time `gorm:"column:created_at" json:"created_at"`
}

func (CoinLedger) TableName() string { return "coin_ledger" }

type UnlockPurchase struct {
	ID         int64      `gorm:"column:id;primaryKey" json:"id"`
	UserID     int64      `gorm:"column:user_id" json:"user_id"`
	DramaID    int64      `gorm:"column:drama_id" json:"drama_id"`
	EpisodeID  int64      `gorm:"column:episode_id" json:"episode_id"`
	UnlockType int8       `gorm:"column:unlock_type" json:"unlock_type"` // 1 ep 2 drama 3 ad
	Price      int        `gorm:"column:price" json:"price"`
	ExpireAt   *time.Time `gorm:"column:expire_at" json:"expire_at"`
	CreatedAt  time.Time  `gorm:"column:created_at" json:"created_at"`
}

func (UnlockPurchase) TableName() string { return "unlock_purchase" }

type AdminUser struct {
	ID        int64     `gorm:"column:id;primaryKey" json:"id"`
	Username  string    `gorm:"column:username" json:"username"`
	Password  string    `gorm:"column:password" json:"-"`
	CreatedAt time.Time `gorm:"column:created_at" json:"created_at"`
}

func (AdminUser) TableName() string { return "admin_user" }
