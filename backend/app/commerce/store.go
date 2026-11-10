package commerce

import (
	"crypto/md5"
	"fmt"
	"time"

	"github.com/yxrxy/videoHub/app/drama"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

func DB() (*gorm.DB, error) { return drama.DB() }

func db() (*gorm.DB, error) { return DB() }

func EnsureWallet(userID int64) (*Wallet, error) {
	d, err := db()
	if err != nil {
		return nil, err
	}
	var w Wallet
	err = d.Where("user_id = ?", userID).First(&w).Error
	if err == gorm.ErrRecordNotFound {
		w = Wallet{UserID: userID, Balance: 100} // 注册赠币
		if err := d.Create(&w).Error; err != nil {
			return nil, err
		}
		_ = addLedger(userID, 100, 100, "register_bonus", "")
		return &w, nil
	}
	if err != nil {
		return nil, err
	}
	return &w, nil
}

func GetBalance(userID int64) (int, error) {
	w, err := EnsureWallet(userID)
	if err != nil {
		return 0, err
	}
	return w.Balance, nil
}

func addLedger(userID int64, change, after int, reason, ref string) error {
	d, err := db()
	if err != nil {
		return err
	}
	return d.Create(&CoinLedger{
		UserID:       userID,
		ChangeAmount: change,
		BalanceAfter: after,
		Reason:       reason,
		RefID:        ref,
	}).Error
}

func ChangeBalance(userID int64, delta int, reason, ref string) (int, error) {
	d, err := db()
	if err != nil {
		return 0, err
	}
	w, err := EnsureWallet(userID)
	if err != nil {
		return 0, err
	}
	newBal := w.Balance + delta
	if newBal < 0 {
		return w.Balance, fmt.Errorf("余额不足")
	}
	if err := d.Model(&Wallet{}).Where("user_id = ?", userID).Update("balance", newBal).Error; err != nil {
		return 0, err
	}
	_ = addLedger(userID, delta, newBal, reason, ref)
	return newBal, nil
}

func ListLedger(userID int64, limit int) ([]CoinLedger, error) {
	d, err := db()
	if err != nil {
		return nil, err
	}
	if limit <= 0 {
		limit = 50
	}
	var list []CoinLedger
	err = d.Where("user_id = ?", userID).Order("id DESC").Limit(limit).Find(&list).Error
	return list, err
}

func HasUnlock(userID, dramaID, episodeID int64) bool {
	d, err := db()
	if err != nil || userID <= 0 {
		return false
	}
	now := time.Now()
	var n int64
	// 整剧
	d.Model(&UnlockPurchase{}).Where("user_id = ? AND drama_id = ? AND unlock_type = 2", userID, dramaID).Count(&n)
	if n > 0 {
		return true
	}
	// 单集或未过期广告
	d.Model(&UnlockPurchase{}).Where(
		"user_id = ? AND drama_id = ? AND episode_id = ? AND (unlock_type = 1 OR (unlock_type = 3 AND (expire_at IS NULL OR expire_at > ?)))",
		userID, dramaID, episodeID, now,
	).Count(&n)
	return n > 0
}

func UnlockEpisode(userID int64, ep *drama.Episode, dr *drama.Drama) (int, error) {
	if drama.IsEpisodeFree(dr, ep) || HasUnlock(userID, dr.ID, ep.ID) {
		bal, _ := GetBalance(userID)
		return bal, nil
	}
	price := ep.UnlockPrice
	if price <= 0 {
		price = 10
	}
	bal, err := ChangeBalance(userID, -price, "unlock", fmt.Sprintf("ep:%d", ep.ID))
	if err != nil {
		return 0, err
	}
	d, err := db()
	if err != nil {
		return bal, err
	}
	err = d.Clauses(clause.OnConflict{DoNothing: true}).Create(&UnlockPurchase{
		UserID:     userID,
		DramaID:    dr.ID,
		EpisodeID:  ep.ID,
		UnlockType: 1,
		Price:      price,
	}).Error
	return bal, err
}

func UnlockDrama(userID int64, dr *drama.Drama) (int, error) {
	if HasUnlock(userID, dr.ID, 0) {
		// check bundle type 2
		d, _ := db()
		var n int64
		d.Model(&UnlockPurchase{}).Where("user_id = ? AND drama_id = ? AND unlock_type = 2", userID, dr.ID).Count(&n)
		if n > 0 {
			return GetBalance(userID)
		}
	}
	price := dr.BundlePrice
	if price <= 0 {
		price = 80
	}
	bal, err := ChangeBalance(userID, -price, "unlock_drama", fmt.Sprintf("drama:%d", dr.ID))
	if err != nil {
		return 0, err
	}
	d, err := db()
	if err != nil {
		return bal, err
	}
	err = d.Clauses(clause.OnConflict{DoNothing: true}).Create(&UnlockPurchase{
		UserID:     userID,
		DramaID:    dr.ID,
		EpisodeID:  0,
		UnlockType: 2,
		Price:      price,
	}).Error
	return bal, err
}

func AdUnlockEpisode(userID int64, ep *drama.Episode, dr *drama.Drama) error {
	expire := time.Now().Add(24 * time.Hour)
	d, err := db()
	if err != nil {
		return err
	}
	return d.Clauses(clause.OnConflict{
		Columns:   []clause.Column{{Name: "user_id"}, {Name: "drama_id"}, {Name: "episode_id"}, {Name: "unlock_type"}},
		DoUpdates: clause.AssignmentColumns([]string{"expire_at", "created_at"}),
	}).Create(&UnlockPurchase{
		UserID:     userID,
		DramaID:    dr.ID,
		EpisodeID:  ep.ID,
		UnlockType: 3,
		Price:      0,
		ExpireAt:   &expire,
	}).Error
}

func AdReward(userID int64) (int, error) {
	return ChangeBalance(userID, 5, "ad_reward", fmt.Sprintf("ad:%d", time.Now().Unix()))
}

func MockTopup(userID int64, amount int) (int, error) {
	if amount <= 0 {
		amount = 100
	}
	return ChangeBalance(userID, amount, "topup", fmt.Sprintf("mock:%d", time.Now().Unix()))
}

func EnsureAdminSeed() error {
	d, err := db()
	if err != nil {
		return err
	}
	var n int64
	d.Model(&AdminUser{}).Count(&n)
	if n > 0 {
		return nil
	}
	hash := fmt.Sprintf("%x", md5.Sum([]byte("admin123")))
	return d.Create(&AdminUser{Username: "admin", Password: hash}).Error
}

func AdminLogin(username, password string) (*AdminUser, error) {
	d, err := db()
	if err != nil {
		return nil, err
	}
	hash := fmt.Sprintf("%x", md5.Sum([]byte(password)))
	var u AdminUser
	if err := d.Where("username = ? AND password = ?", username, hash).First(&u).Error; err != nil {
		return nil, fmt.Errorf("账号或密码错误")
	}
	return &u, nil
}

func init() {
	drama.HasUnlock = HasUnlock
}
