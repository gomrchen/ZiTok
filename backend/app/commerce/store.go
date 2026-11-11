package commerce

import (
	"crypto/md5"
	"database/sql"
	"fmt"
	"strconv"
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

func ListRecentLedger(limit int) ([]CoinLedger, error) {
	d, err := db()
	if err != nil {
		return nil, err
	}
	if limit <= 0 {
		limit = 50
	}
	var list []CoinLedger
	err = d.Order("id DESC").Limit(limit).Find(&list).Error
	return list, err
}

func ListRecentUnlocks(limit int) ([]UnlockPurchase, error) {
	return ListUnlocksFiltered(0, 0, limit)
}

func ListUnlocksFiltered(userID, dramaID int64, limit int) ([]UnlockPurchase, error) {
	return ListUnlocksQuery(userID, dramaID, 0, limit)
}

func ListUnlocksQuery(userID, dramaID int64, unlockType int8, limit int) ([]UnlockPurchase, error) {
	d, err := db()
	if err != nil {
		return nil, err
	}
	if limit <= 0 {
		limit = 50
	}
	q := d.Model(&UnlockPurchase{})
	if userID > 0 {
		q = q.Where("user_id = ?", userID)
	}
	if dramaID > 0 {
		q = q.Where("drama_id = ?", dramaID)
	}
	if unlockType > 0 {
		q = q.Where("unlock_type = ?", unlockType)
	}
	var list []UnlockPurchase
	err = q.Order("id DESC").Limit(limit).Find(&list).Error
	return list, err
}

type UnlockView struct {
	ID         int64      `json:"id"`
	UserID     int64      `json:"user_id"`
	Username   string     `json:"username"`
	DramaID    int64      `json:"drama_id"`
	DramaTitle string     `json:"drama_title"`
	EpisodeID  int64      `json:"episode_id"`
	UnlockType int8       `json:"unlock_type"`
	Price      int        `json:"price"`
	ExpireAt   *time.Time `json:"expire_at"`
	Expired    bool       `json:"expired"`
	CreatedAt  time.Time  `json:"created_at"`
}

func ListUnlocksEnriched(userID, dramaID int64, unlockType int8, limit int, expiredOnly bool) ([]UnlockView, error) {
	d, err := db()
	if err != nil {
		return nil, err
	}
	if limit <= 0 {
		limit = 50
	}
	if limit > 200 {
		limit = 200
	}
	q := d.Table("unlock_purchase AS u").
		Select(`u.id, u.user_id, COALESCE(usr.username,'') AS username,
			u.drama_id, COALESCE(dr.title,'') AS drama_title,
			u.episode_id, u.unlock_type, u.price, u.expire_at, u.created_at`).
		Joins("LEFT JOIN users usr ON usr.id = u.user_id").
		Joins("LEFT JOIN drama dr ON dr.id = u.drama_id")
	if userID > 0 {
		q = q.Where("u.user_id = ?", userID)
	}
	if dramaID > 0 {
		q = q.Where("u.drama_id = ?", dramaID)
	}
	if unlockType > 0 {
		q = q.Where("u.unlock_type = ?", unlockType)
	}
	if expiredOnly {
		q = q.Where("u.expire_at IS NOT NULL AND u.expire_at < ?", time.Now())
	}
	var list []UnlockView
	err = q.Order("u.id DESC").Limit(limit).Scan(&list).Error
	if err != nil {
		return nil, err
	}
	now := time.Now()
	for i := range list {
		if list[i].ExpireAt != nil && list[i].ExpireAt.Before(now) {
			list[i].Expired = true
		}
	}
	return list, nil
}

type UserCommerceSummary struct {
	Username      string     `json:"username"`
	AvatarURL     string     `json:"avatar_url"`
	CreatedAt     *time.Time `json:"created_at,omitempty"`
	TopupSum      int64      `json:"topup_sum"`
	SpendSum      int64      `json:"spend_sum"`
	UnlockCount   int64      `json:"unlock_count"`
	LastWatchAt   *time.Time `json:"last_watch_at,omitempty"`
}

func GetUserCommerceSummary(userID int64) (*UserCommerceSummary, error) {
	d, err := db()
	if err != nil {
		return nil, err
	}
	s := &UserCommerceSummary{}
	type urow struct {
		Username  string
		AvatarURL string
		CreatedAt time.Time
	}
	var u urow
	if err := d.Table("users").Select("username, avatar_url, created_at").Where("id = ?", userID).Scan(&u).Error; err == nil {
		s.Username = u.Username
		s.AvatarURL = u.AvatarURL
		if !u.CreatedAt.IsZero() {
			t := u.CreatedAt
			s.CreatedAt = &t
		}
	}
	_ = d.Table("coin_ledger").Where("user_id = ? AND (reason IN ? OR reason LIKE ?)", userID,
		[]string{"topup", "mock_topup", "admin_topup"}, "topup%").
		Select("COALESCE(SUM(change_amount),0)").Scan(&s.TopupSum).Error
	_ = d.Table("coin_ledger").Where("user_id = ? AND change_amount < 0", userID).
		Select("COALESCE(SUM(-change_amount),0)").Scan(&s.SpendSum).Error
	_ = d.Model(&UnlockPurchase{}).Where("user_id = ?", userID).Count(&s.UnlockCount).Error
	var last sql.NullTime
	if err := d.Raw("SELECT MAX(updated_at) FROM user_watch_progress WHERE user_id = ?", userID).
		Scan(&last).Error; err == nil && last.Valid {
		t := last.Time
		s.LastWatchAt = &t
	}
	return s, nil
}

func ListTopups(limit int) ([]CoinLedger, error) {
	return ListTopupsFiltered(0, limit)
}

func ListTopupsFiltered(userID int64, limit int) ([]CoinLedger, error) {
	d, err := db()
	if err != nil {
		return nil, err
	}
	if limit <= 0 {
		limit = 50
	}
	q := d.Where("reason IN ? OR reason LIKE ?", []string{"topup", "mock_topup", "admin_topup"}, "topup%")
	if userID > 0 {
		q = q.Where("user_id = ?", userID)
	}
	var list []CoinLedger
	err = q.Order("id DESC").Limit(limit).Find(&list).Error
	return list, err
}

func ListLedgerFiltered(userID int64, reason string, limit int) ([]CoinLedger, error) {
	d, err := db()
	if err != nil {
		return nil, err
	}
	if limit <= 0 {
		limit = 50
	}
	q := d.Model(&CoinLedger{})
	if userID > 0 {
		q = q.Where("user_id = ?", userID)
	}
	if reason != "" {
		q = q.Where("reason = ? OR reason LIKE ?", reason, reason+"%")
	}
	var list []CoinLedger
	err = q.Order("id DESC").Limit(limit).Find(&list).Error
	return list, err
}

func ChangeAdminPassword(adminID int64, oldPwd, newPwd string) error {
	if newPwd == "" || len(newPwd) < 6 {
		return fmt.Errorf("新密码至少 6 位")
	}
	d, err := db()
	if err != nil {
		return err
	}
	var u AdminUser
	if err := d.Where("id = ?", adminID).First(&u).Error; err != nil {
		return fmt.Errorf("账号不存在")
	}
	oldHash := fmt.Sprintf("%x", md5.Sum([]byte(oldPwd)))
	if u.Password != oldHash {
		return fmt.Errorf("原密码错误")
	}
	newHash := fmt.Sprintf("%x", md5.Sum([]byte(newPwd)))
	return d.Model(&AdminUser{}).Where("id = ?", adminID).Update("password", newHash).Error
}

type UnlockTypeStat struct {
	UnlockType int8  `json:"unlock_type"`
	Count      int64 `json:"count"`
	Revenue    int64 `json:"revenue"`
}

func ListUnlockTypeStats() ([]UnlockTypeStat, error) {
	d, err := db()
	if err != nil {
		return nil, err
	}
	type row struct {
		UnlockType int8
		Count      int64
		Revenue    int64
	}
	var rows []row
	err = d.Raw(`
		SELECT unlock_type,
		       COUNT(*) AS count,
		       COALESCE(SUM(price),0) AS revenue
		FROM unlock_purchase
		GROUP BY unlock_type
		ORDER BY unlock_type
	`).Scan(&rows).Error
	if err != nil {
		return nil, err
	}
	out := make([]UnlockTypeStat, 0, len(rows))
	for _, r := range rows {
		out = append(out, UnlockTypeStat{UnlockType: r.UnlockType, Count: r.Count, Revenue: r.Revenue})
	}
	return out, nil
}

type UserBrief struct {
	ID        int64  `json:"id"`
	Username  string `json:"username"`
	AvatarURL string `json:"avatar_url"`
	Balance   int    `json:"balance"`
}

func SearchUsers(keyword string, limit int) ([]UserBrief, error) {
	d, err := db()
	if err != nil {
		return nil, err
	}
	if limit <= 0 || limit > 50 {
		limit = 20
	}
	type row struct {
		ID        int64  `gorm:"column:id"`
		Username  string `gorm:"column:username"`
		AvatarURL string `gorm:"column:avatar_url"`
	}
	var users []row
	q := d.Table("users").Select("id, username, avatar_url").Where("deleted_at IS NULL")
	if keyword != "" {
		if id, e := strconv.ParseInt(keyword, 10, 64); e == nil && id > 0 {
			q = q.Where("id = ? OR username LIKE ?", id, "%"+keyword+"%")
		} else {
			q = q.Where("username LIKE ?", "%"+keyword+"%")
		}
	}
	if err := q.Order("id DESC").Limit(limit).Find(&users).Error; err != nil {
		return nil, err
	}
	out := make([]UserBrief, 0, len(users))
	for _, u := range users {
		bal, _ := GetBalance(u.ID)
		out = append(out, UserBrief{
			ID:        u.ID,
			Username:  u.Username,
			AvatarURL: u.AvatarURL,
			Balance:   bal,
		})
	}
	return out, nil
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

// GrantUnlock 运营赠送解锁（不扣币）
func GrantUnlock(userID, dramaID, episodeID int64, unlockType int8) error {
	if userID <= 0 || dramaID <= 0 {
		return fmt.Errorf("参数无效")
	}
	if unlockType != 1 && unlockType != 2 && unlockType != 3 {
		unlockType = 1
	}
	if unlockType == 2 {
		episodeID = 0
	}
	if unlockType == 1 && episodeID <= 0 {
		return fmt.Errorf("单集解锁需要 episode_id")
	}
	d, err := db()
	if err != nil {
		return err
	}
	rec := &UnlockPurchase{
		UserID:     userID,
		DramaID:    dramaID,
		EpisodeID:  episodeID,
		UnlockType: unlockType,
		Price:      0,
	}
	if unlockType == 3 {
		exp := time.Now().Add(24 * time.Hour)
		rec.ExpireAt = &exp
	}
	return d.Clauses(clause.OnConflict{DoNothing: true}).Create(rec).Error
}

// RevokeUnlock 撤销解锁；refund=true 时按原价退回金币
func RevokeUnlock(id int64, refund bool) error {
	d, err := db()
	if err != nil {
		return err
	}
	var u UnlockPurchase
	if err := d.Where("id = ?", id).First(&u).Error; err != nil {
		return err
	}
	if err := d.Delete(&UnlockPurchase{}, id).Error; err != nil {
		return err
	}
	if refund && u.Price > 0 {
		_, err = ChangeBalance(u.UserID, u.Price, "unlock_refund", fmt.Sprintf("unlock:%d", id))
		return err
	}
	return nil
}

func ListUsers(keyword string, page, size int) ([]UserBrief, int64, error) {
	return ListUsersSorted(keyword, page, size, "")
}

func ListUsersSorted(keyword string, page, size int, sort string) ([]UserBrief, int64, error) {
	d, err := db()
	if err != nil {
		return nil, 0, err
	}
	if page < 1 {
		page = 1
	}
	if size < 1 || size > 50 {
		size = 20
	}
	type row struct {
		ID        int64  `gorm:"column:id"`
		Username  string `gorm:"column:username"`
		AvatarURL string `gorm:"column:avatar_url"`
		Balance   int    `gorm:"column:balance"`
	}
	base := d.Table("users u").
		Joins("LEFT JOIN wallet w ON w.user_id = u.id").
		Where("u.deleted_at IS NULL")
	if keyword != "" {
		if id, e := strconv.ParseInt(keyword, 10, 64); e == nil && id > 0 {
			base = base.Where("u.id = ? OR u.username LIKE ?", id, "%"+keyword+"%")
		} else {
			base = base.Where("u.username LIKE ?", "%"+keyword+"%")
		}
	}
	var total int64
	if err := base.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	order := "u.id DESC"
	switch sort {
	case "balance_desc":
		order = "COALESCE(w.balance,0) DESC, u.id DESC"
	case "balance_asc":
		order = "COALESCE(w.balance,0) ASC, u.id DESC"
	case "id_asc":
		order = "u.id ASC"
	}
	var users []row
	if err := base.Select("u.id, u.username, u.avatar_url, COALESCE(w.balance,0) AS balance").
		Order(order).Offset((page - 1) * size).Limit(size).Find(&users).Error; err != nil {
		return nil, 0, err
	}
	out := make([]UserBrief, 0, len(users))
	for _, u := range users {
		out = append(out, UserBrief{
			ID: u.ID, Username: u.Username, AvatarURL: u.AvatarURL, Balance: u.Balance,
		})
	}
	return out, total, nil
}

type RevenueSnapshot struct {
	UnlockRevenue  int64 `json:"unlock_revenue"`
	TodayUnlocks   int64 `json:"today_unlocks"`
	TodayRevenue   int64 `json:"today_revenue"`
	TodayTopupAmt  int64 `json:"today_topup_amt"`
	TodayTopupCnt  int64 `json:"today_topup_cnt"`
	AdUnlockCount  int64 `json:"ad_unlock_count"`
}

func GetRevenueSnapshot() (*RevenueSnapshot, error) {
	d, err := db()
	if err != nil {
		return nil, err
	}
	s := &RevenueSnapshot{}
	d.Model(&UnlockPurchase{}).Select("COALESCE(SUM(price),0)").Scan(&s.UnlockRevenue)
	d.Model(&UnlockPurchase{}).Where("unlock_type = 3").Count(&s.AdUnlockCount)
	start := time.Now().Truncate(24 * time.Hour)
	d.Model(&UnlockPurchase{}).Where("created_at >= ?", start).Count(&s.TodayUnlocks)
	d.Model(&UnlockPurchase{}).Where("created_at >= ?", start).Select("COALESCE(SUM(price),0)").Scan(&s.TodayRevenue)
	d.Model(&CoinLedger{}).Where("created_at >= ? AND (reason IN ? OR reason LIKE ?)", start,
		[]string{"topup", "mock_topup", "admin_topup"}, "topup%").Count(&s.TodayTopupCnt)
	d.Model(&CoinLedger{}).Where("created_at >= ? AND (reason IN ? OR reason LIKE ?)", start,
		[]string{"topup", "mock_topup", "admin_topup"}, "topup%").
		Select("COALESCE(SUM(change_amount),0)").Scan(&s.TodayTopupAmt)
	return s, nil
}

type DailyRevenuePoint struct {
	Date    string `json:"date"`
	Revenue int64  `json:"revenue"`
	Count   int64  `json:"count"`
}

func ListDailySignups(days int) ([]DailyRevenuePoint, error) {
	if days <= 0 {
		days = 7
	}
	if days > 30 {
		days = 30
	}
	d, err := db()
	if err != nil {
		return nil, err
	}
	now := time.Now()
	start := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location()).AddDate(0, 0, -(days - 1))
	type row struct {
		Day   string
		Count int64
	}
	var rows []row
	_ = d.Raw(`
		SELECT DATE_FORMAT(created_at, '%Y-%m-%d') AS day, COUNT(*) AS count
		FROM users WHERE deleted_at IS NULL AND created_at >= ?
		GROUP BY DATE_FORMAT(created_at, '%Y-%m-%d') ORDER BY day
	`, start).Scan(&rows)
	byDay := map[string]int64{}
	for _, r := range rows {
		byDay[r.Day] = r.Count
	}
	out := make([]DailyRevenuePoint, 0, days)
	for i := 0; i < days; i++ {
		day := start.AddDate(0, 0, i).Format("2006-01-02")
		out = append(out, DailyRevenuePoint{Date: day, Count: byDay[day]})
	}
	return out, nil
}

func ListDailyTopups(days int) ([]DailyRevenuePoint, error) {
	if days <= 0 {
		days = 7
	}
	if days > 30 {
		days = 30
	}
	d, err := db()
	if err != nil {
		return nil, err
	}
	now := time.Now()
	start := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location()).AddDate(0, 0, -(days - 1))
	type row struct {
		Day     string
		Revenue int64
		Count   int64
	}
	var rows []row
	_ = d.Raw(`
		SELECT DATE_FORMAT(created_at, '%Y-%m-%d') AS day,
		       COALESCE(SUM(change_amount),0) AS revenue,
		       COUNT(*) AS count
		FROM coin_ledger
		WHERE created_at >= ? AND (reason IN ('topup','mock_topup','admin_topup') OR reason LIKE 'topup%')
		GROUP BY DATE_FORMAT(created_at, '%Y-%m-%d') ORDER BY day
	`, start).Scan(&rows)
	byDay := map[string]row{}
	for _, r := range rows {
		byDay[r.Day] = r
	}
	out := make([]DailyRevenuePoint, 0, days)
	for i := 0; i < days; i++ {
		day := start.AddDate(0, 0, i).Format("2006-01-02")
		r := byDay[day]
		out = append(out, DailyRevenuePoint{Date: day, Revenue: r.Revenue, Count: r.Count})
	}
	return out, nil
}

// ListDailyRevenue returns last N calendar days of unlock revenue (including empty days).
func ListDailyRevenue(days int) ([]DailyRevenuePoint, error) {
	if days <= 0 {
		days = 7
	}
	if days > 30 {
		days = 30
	}
	d, err := db()
	if err != nil {
		return nil, err
	}
	now := time.Now()
	start := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location()).AddDate(0, 0, -(days - 1))
	type row struct {
		Day     string
		Revenue int64
		Count   int64
	}
	var rows []row
	err = d.Raw(`
		SELECT DATE_FORMAT(created_at, '%Y-%m-%d') AS day,
		       COALESCE(SUM(price),0) AS revenue,
		       COUNT(*) AS count
		FROM unlock_purchase
		WHERE created_at >= ?
		GROUP BY DATE_FORMAT(created_at, '%Y-%m-%d')
		ORDER BY day
	`, start).Scan(&rows).Error
	if err != nil {
		return nil, err
	}
	byDay := map[string]row{}
	for _, r := range rows {
		byDay[r.Day] = r
	}
	out := make([]DailyRevenuePoint, 0, days)
	for i := 0; i < days; i++ {
		day := start.AddDate(0, 0, i).Format("2006-01-02")
		r := byDay[day]
		out = append(out, DailyRevenuePoint{Date: day, Revenue: r.Revenue, Count: r.Count})
	}
	return out, nil
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
