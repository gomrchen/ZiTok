package drama

import (
	"fmt"
	"image"
	"image/color"
	"image/jpeg"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/yxrxy/videoHub/pkg/base/client"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

var (
	dbOnce sync.Once
	dbInst *gorm.DB
	dbErr  error
)

func DB() (*gorm.DB, error) {
	dbOnce.Do(func() {
		dbInst, dbErr = client.InitMySQL()
	})
	return dbInst, dbErr
}

// ListDramas status: nil=仅上架(1)；非 nil 按值过滤；传 statusAll 指针表示不过滤状态。
var StatusAll int8 = -1

func ListDramas(page, size int, category string, status *int8) ([]Drama, int64, error) {
	return ListDramasFiltered(page, size, category, "", status)
}

// ListDramasFiltered 支持分类 / 关键词 / 状态筛选（运营后台用）
// status=-2 表示仅已软删
func ListDramasFiltered(page, size int, category, keyword string, status *int8) ([]Drama, int64, error) {
	return ListDramasFilteredSort(page, size, category, keyword, status, "")
}

func ListDramasFilteredSort(page, size int, category, keyword string, status *int8, sort string) ([]Drama, int64, error) {
	db, err := DB()
	if err != nil {
		return nil, 0, err
	}
	if page < 1 {
		page = 1
	}
	if size < 1 || size > 100 {
		size = 20
	}
	q := db.Model(&Drama{})
	if status != nil && *status == -2 {
		q = q.Where("deleted_at IS NOT NULL")
	} else {
		q = q.Where("deleted_at IS NULL")
		if status == nil {
			q = q.Where("status = 1")
		} else if *status != StatusAll {
			q = q.Where("status = ?", *status)
		}
	}
	if category != "" {
		q = q.Where("category = ?", category)
	}
	if keyword != "" {
		like := "%" + keyword + "%"
		q = q.Where("title LIKE ? OR description LIKE ? OR tags LIKE ?", like, like, like)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	order := "updated_at DESC, id DESC"
	switch sort {
	case "play_desc":
		order = "play_count DESC, id DESC"
	case "play_asc":
		order = "play_count ASC, id ASC"
	case "created_desc":
		order = "created_at DESC, id DESC"
	case "id_asc":
		order = "id ASC"
	case "revenue_desc":
		// 按解锁收入排序：子查询汇总后回填
		type row struct {
			Drama
			Rev int64 `gorm:"column:unlock_revenue"`
		}
		var rows []row
		base := q.Session(&gorm.Session{})
		err = base.Select("drama.*, COALESCE((SELECT SUM(price) FROM unlock_purchase u WHERE u.drama_id = drama.id),0) AS unlock_revenue").
			Order("unlock_revenue DESC, id DESC").
			Offset((page - 1) * size).Limit(size).Scan(&rows).Error
		if err != nil {
			return nil, 0, err
		}
		list := make([]Drama, 0, len(rows))
		for _, r := range rows {
			item := r.Drama
			item.UnlockRevenue = r.Rev
			list = append(list, item)
		}
		return list, total, nil
	}
	var list []Drama
	err = q.Order(order).Offset((page - 1) * size).Limit(size).Find(&list).Error
	if err != nil {
		return nil, 0, err
	}
	for i := range list {
		var rev int64
		db.Table("unlock_purchase").Where("drama_id = ?", list[i].ID).Select("COALESCE(SUM(price),0)").Scan(&rev)
		list[i].UnlockRevenue = rev
	}
	return list, total, nil
}

func GetDrama(id int64) (*Drama, error) {
	db, err := DB()
	if err != nil {
		return nil, err
	}
	var d Drama
	if err := db.Where("id = ? AND deleted_at IS NULL", id).First(&d).Error; err != nil {
		return nil, err
	}
	return &d, nil
}

func ListEpisodes(dramaID int64) ([]Episode, error) {
	db, err := DB()
	if err != nil {
		return nil, err
	}
	var list []Episode
	err = db.Where("drama_id = ? AND deleted_at IS NULL", dramaID).Order("episode_no ASC").Find(&list).Error
	return list, err
}

func GetEpisode(id int64) (*Episode, error) {
	db, err := DB()
	if err != nil {
		return nil, err
	}
	var ep Episode
	if err := db.Where("id = ? AND deleted_at IS NULL", id).First(&ep).Error; err != nil {
		return nil, err
	}
	return &ep, nil
}

func GetEpisodeByNo(dramaID int64, no int) (*Episode, error) {
	db, err := DB()
	if err != nil {
		return nil, err
	}
	var ep Episode
	if err := db.Where("drama_id = ? AND episode_no = ? AND deleted_at IS NULL", dramaID, no).First(&ep).Error; err != nil {
		return nil, err
	}
	return &ep, nil
}

func CreateDrama(d *Drama) error {
	db, err := DB()
	if err != nil {
		return err
	}
	return db.Create(d).Error
}

func UpdateDrama(d *Drama) error {
	db, err := DB()
	if err != nil {
		return err
	}
	return db.Model(d).Updates(d).Error
}

func CreateEpisode(ep *Episode) error {
	db, err := DB()
	if err != nil {
		return err
	}
	if err := db.Create(ep).Error; err != nil {
		return err
	}
	return db.Model(&Drama{}).Where("id = ?", ep.DramaID).
		UpdateColumn("total_episodes", gorm.Expr("total_episodes + 1")).Error
}

func UpdateEpisode(ep *Episode) error {
	db, err := DB()
	if err != nil {
		return err
	}
	return db.Model(ep).Updates(ep).Error
}

func SoftDeleteDrama(id int64) error {
	db, err := DB()
	if err != nil {
		return err
	}
	now := time.Now()
	return db.Model(&Drama{}).Where("id = ? AND deleted_at IS NULL", id).Updates(map[string]any{
		"deleted_at": now,
		"status":     int8(2),
	}).Error
}

func RestoreDrama(id int64) error {
	db, err := DB()
	if err != nil {
		return err
	}
	return db.Model(&Drama{}).Where("id = ?", id).Updates(map[string]any{
		"deleted_at": nil,
		"status":     int8(2), // 恢复后默认下架，需手动上架
	}).Error
}

func BatchRestoreDramas(ids []int64) (int64, error) {
	db, err := DB()
	if err != nil {
		return 0, err
	}
	if len(ids) == 0 {
		return 0, nil
	}
	res := db.Model(&Drama{}).Where("id IN ? AND deleted_at IS NOT NULL", ids).Updates(map[string]any{
		"deleted_at": nil,
		"status":     int8(2),
	})
	return res.RowsAffected, res.Error
}

func HardDeleteDrama(id int64) error {
	db, err := DB()
	if err != nil {
		return err
	}
	now := time.Now()
	_ = db.Model(&Episode{}).Where("drama_id = ?", id).Update("deleted_at", now).Error
	return db.Unscoped().Where("id = ?", id).Delete(&Drama{}).Error
}

func BatchHardDeleteDramas(ids []int64) (int64, error) {
	if len(ids) == 0 {
		return 0, nil
	}
	var n int64
	for _, id := range ids {
		if err := HardDeleteDrama(id); err != nil {
			return n, err
		}
		n++
	}
	return n, nil
}

func ensureCategoryTable(db *gorm.DB) error {
	return db.AutoMigrate(&CategoryCatalog{})
}

func CreateCategory(name string, sortOrder int) error {
	db, err := DB()
	if err != nil {
		return err
	}
	if err := ensureCategoryTable(db); err != nil {
		return err
	}
	name = trimSpace(name)
	if name == "" {
		return fmt.Errorf("分类名不能为空")
	}
	if len([]rune(name)) > 32 {
		return fmt.Errorf("分类名过长")
	}
	var n int64
	_ = db.Model(&CategoryCatalog{}).Where("name = ?", name).Count(&n).Error
	if n > 0 {
		return fmt.Errorf("分类已存在")
	}
	// 剧目里已有同名也视为存在
	_ = db.Model(&Drama{}).Where("deleted_at IS NULL AND category = ?", name).Count(&n).Error
	if n > 0 {
		// 同步进目录即可
		return db.Clauses(clause.OnConflict{DoNothing: true}).Create(&CategoryCatalog{Name: name, SortOrder: sortOrder}).Error
	}
	return db.Create(&CategoryCatalog{Name: name, SortOrder: sortOrder}).Error
}

func RenameCategory(from, to string) (int64, error) {
	db, err := DB()
	if err != nil {
		return 0, err
	}
	_ = ensureCategoryTable(db)
	from = trimSpace(from)
	to = trimSpace(to)
	if from == "" || to == "" {
		return 0, fmt.Errorf("分类名不能为空")
	}
	if from == to {
		return 0, nil
	}
	var exist int64
	_ = db.Model(&Drama{}).Where("deleted_at IS NULL AND category = ?", to).Count(&exist).Error
	if exist == 0 {
		_ = db.Model(&CategoryCatalog{}).Where("name = ?", to).Count(&exist).Error
	}
	if exist > 0 {
		return 0, fmt.Errorf("目标分类已存在")
	}
	res := db.Model(&Drama{}).Where("deleted_at IS NULL AND category = ?", from).Update("category", to)
	if res.Error != nil {
		return 0, res.Error
	}
	sortOrder := 0
	var cat CategoryCatalog
	if err := db.Where("name = ?", from).First(&cat).Error; err == nil {
		sortOrder = cat.SortOrder
		_ = db.Delete(&CategoryCatalog{}, "name = ?", from).Error
	}
	_ = db.Clauses(clause.OnConflict{DoNothing: true}).Create(&CategoryCatalog{Name: to, SortOrder: sortOrder}).Error
	return res.RowsAffected, nil
}

// DeleteCategory 删除分类。moveTo 非空时把剧目迁移过去；为空则要求该分类下无剧目。
func DeleteCategory(name, moveTo string) (int64, error) {
	db, err := DB()
	if err != nil {
		return 0, err
	}
	_ = ensureCategoryTable(db)
	name = trimSpace(name)
	moveTo = trimSpace(moveTo)
	if name == "" {
		return 0, fmt.Errorf("分类名不能为空")
	}
	var moved int64
	var cnt int64
	_ = db.Model(&Drama{}).Where("deleted_at IS NULL AND category = ?", name).Count(&cnt).Error
	if cnt > 0 {
		if moveTo == "" {
			return 0, fmt.Errorf("分类下仍有 %d 部剧，请先迁移或填写 move_to", cnt)
		}
		if moveTo == name {
			return 0, fmt.Errorf("迁移目标不能与原分类相同")
		}
		res := db.Model(&Drama{}).Where("deleted_at IS NULL AND category = ?", name).Update("category", moveTo)
		if res.Error != nil {
			return 0, res.Error
		}
		moved = res.RowsAffected
		_ = db.Clauses(clause.OnConflict{DoNothing: true}).Create(&CategoryCatalog{Name: moveTo}).Error
	}
	_ = db.Delete(&CategoryCatalog{}, "name = ?", name).Error
	return moved, nil
}

func trimSpace(s string) string {
	for len(s) > 0 && (s[0] == ' ' || s[0] == '\t') {
		s = s[1:]
	}
	for len(s) > 0 && (s[len(s)-1] == ' ' || s[len(s)-1] == '\t') {
		s = s[:len(s)-1]
	}
	return s
}

type CategoryStat struct {
	Category   string `json:"category"`
	Total      int64  `json:"total"`
	Online     int64  `json:"online"`
	PlaySum    int64  `json:"play_sum"`
	RevenueSum int64  `json:"revenue_sum"`
}

func ListCategoryStats() ([]CategoryStat, error) {
	db, err := DB()
	if err != nil {
		return nil, err
	}
	_ = ensureCategoryTable(db)
	type row struct {
		Category   string
		Total      int64
		Online     int64
		PlaySum    int64
		RevenueSum int64
	}
	var rows []row
	err = db.Raw(`
		SELECT d.category AS category,
		       COUNT(DISTINCT d.id) AS total,
		       SUM(CASE WHEN d.status = 1 THEN 1 ELSE 0 END) AS online,
		       COALESCE(SUM(d.play_count),0) AS play_sum,
		       COALESCE((
		         SELECT SUM(u.price) FROM unlock_purchase u
		         INNER JOIN drama d2 ON d2.id = u.drama_id
		         WHERE d2.deleted_at IS NULL AND d2.category = d.category
		       ),0) AS revenue_sum
		FROM drama d
		WHERE d.deleted_at IS NULL AND d.category <> ''
		GROUP BY d.category
		ORDER BY revenue_sum DESC, total DESC, d.category ASC
	`).Scan(&rows).Error
	if err != nil {
		return nil, err
	}
	byName := map[string]CategoryStat{}
	for _, r := range rows {
		byName[r.Category] = CategoryStat{
			Category: r.Category, Total: r.Total, Online: r.Online, PlaySum: r.PlaySum, RevenueSum: r.RevenueSum,
		}
	}
	var catalog []CategoryCatalog
	_ = db.Order("sort_order ASC, name ASC").Find(&catalog).Error
	for _, c := range catalog {
		if _, ok := byName[c.Name]; !ok {
			byName[c.Name] = CategoryStat{Category: c.Name}
		}
	}
	out := make([]CategoryStat, 0, len(byName))
	for _, v := range byName {
		out = append(out, v)
	}
	// 稳定排序：收入 desc, 总量 desc, 名 asc
	for i := 0; i < len(out); i++ {
		for j := i + 1; j < len(out); j++ {
			a, b := out[i], out[j]
			swap := false
			if a.RevenueSum != b.RevenueSum {
				swap = a.RevenueSum < b.RevenueSum
			} else if a.Total != b.Total {
				swap = a.Total < b.Total
			} else {
				swap = a.Category > b.Category
			}
			if swap {
				out[i], out[j] = out[j], out[i]
			}
		}
	}
	return out, nil
}

func ListTopDramasBy(sort string, limit int) ([]Drama, error) {
	db, err := DB()
	if err != nil {
		return nil, err
	}
	if limit <= 0 {
		limit = 10
	}
	if sort == "unlock" || sort == "revenue" {
		type row struct {
			Drama
			Rev int64 `gorm:"column:rev"`
		}
		var rows []row
		err = db.Raw(`
			SELECT d.*, COALESCE(SUM(u.price),0) AS rev
			FROM drama d
			LEFT JOIN unlock_purchase u ON u.drama_id = d.id
			WHERE d.deleted_at IS NULL
			GROUP BY d.id
			ORDER BY rev DESC, d.play_count DESC, d.id DESC
			LIMIT ?
		`, limit).Scan(&rows).Error
		if err != nil {
			return nil, err
		}
		list := make([]Drama, 0, len(rows))
		for _, r := range rows {
			item := r.Drama
			item.UnlockRevenue = r.Rev
			list = append(list, item)
		}
		return list, nil
	}
	list, err := ListTopDramas(limit)
	if err != nil {
		return nil, err
	}
	// 播放榜也附带收入，方便对照
	for i := range list {
		var rev int64
		db.Table("unlock_purchase").Where("drama_id = ?", list[i].ID).Select("COALESCE(SUM(price),0)").Scan(&rev)
		list[i].UnlockRevenue = rev
	}
	return list, nil
}

type EpisodeOpsStat struct {
	ID            int64  `json:"id"`
	DramaID       int64  `json:"drama_id"`
	EpisodeNo     int    `json:"episode_no"`
	Title         string `json:"title"`
	IsFree        bool   `json:"is_free"`
	UnlockPrice   int    `json:"unlock_price"`
	VisitCount    int64  `json:"visit_count"`
	Duration      int64  `json:"duration"`
	UnlockCount   int64  `json:"unlock_count"`
	UnlockRevenue int64  `json:"unlock_revenue"`
}

func ListEpisodeOpsStats(dramaID int64) ([]EpisodeOpsStat, error) {
	db, err := DB()
	if err != nil {
		return nil, err
	}
	var rows []EpisodeOpsStat
	err = db.Raw(`
		SELECT e.id, e.drama_id, e.episode_no, e.title, e.is_free, e.unlock_price,
		       e.visit_count, e.duration,
		       COALESCE(COUNT(u.id),0) AS unlock_count,
		       COALESCE(SUM(u.price),0) AS unlock_revenue
		FROM episode e
		LEFT JOIN unlock_purchase u ON u.episode_id = e.id AND u.unlock_type = 1
		WHERE e.drama_id = ? AND e.deleted_at IS NULL
		GROUP BY e.id
		ORDER BY e.episode_no ASC
	`, dramaID).Scan(&rows).Error
	return rows, err
}

func SetDramaStatus(id int64, status int8) error {
	db, err := DB()
	if err != nil {
		return err
	}
	return db.Model(&Drama{}).Where("id = ? AND deleted_at IS NULL", id).Update("status", status).Error
}

func ListCategories() ([]string, error) {
	db, err := DB()
	if err != nil {
		return nil, err
	}
	_ = ensureCategoryTable(db)
	seen := map[string]struct{}{}
	var cats []string
	var fromDrama []string
	_ = db.Model(&Drama{}).Where("deleted_at IS NULL AND category <> ''").
		Distinct().Order("category ASC").Pluck("category", &fromDrama).Error
	for _, c := range fromDrama {
		if _, ok := seen[c]; ok {
			continue
		}
		seen[c] = struct{}{}
		cats = append(cats, c)
	}
	var catalog []CategoryCatalog
	_ = db.Order("sort_order ASC, name ASC").Find(&catalog).Error
	for _, c := range catalog {
		if _, ok := seen[c.Name]; ok {
			continue
		}
		seen[c.Name] = struct{}{}
		cats = append(cats, c.Name)
	}
	return cats, nil
}

type DramaOpsStat struct {
	DramaID      int64  `json:"drama_id"`
	Title        string `json:"title"`
	Status       int8   `json:"status"`
	PlayCount    int64  `json:"play_count"`
	EpisodeCount int64  `json:"episode_count"`
	UnlockCount  int64  `json:"unlock_count"`
	UnlockRevenue int64 `json:"unlock_revenue"`
	WatchingCount int64 `json:"watching_count"`
	FavCount     int64  `json:"fav_count"`
}

func GetDramaOpsStat(id int64) (*DramaOpsStat, error) {
	db, err := DB()
	if err != nil {
		return nil, err
	}
	d, err := GetDrama(id)
	if err != nil {
		return nil, err
	}
	st := &DramaOpsStat{
		DramaID:   d.ID,
		Title:     d.Title,
		Status:    d.Status,
		PlayCount: d.PlayCount,
	}
	db.Model(&Episode{}).Where("drama_id = ? AND deleted_at IS NULL", id).Count(&st.EpisodeCount)
	db.Table("unlock_purchase").Where("drama_id = ?", id).Count(&st.UnlockCount)
	db.Table("unlock_purchase").Where("drama_id = ?", id).Select("COALESCE(SUM(price),0)").Scan(&st.UnlockRevenue)
	db.Model(&WatchProgress{}).Where("drama_id = ?", id).Count(&st.WatchingCount)
	db.Model(&DramaFavorite{}).Where("drama_id = ?", id).Count(&st.FavCount)
	return st, nil
}

func BatchSetDramaStatus(ids []int64, status int8) (int64, error) {
	db, err := DB()
	if err != nil {
		return 0, err
	}
	if len(ids) == 0 {
		return 0, nil
	}
	res := db.Model(&Drama{}).Where("id IN ? AND deleted_at IS NULL", ids).Update("status", status)
	return res.RowsAffected, res.Error
}

func SetEpisodeNo(episodeID int64, newNo int) error {
	db, err := DB()
	if err != nil {
		return err
	}
	if newNo <= 0 {
		return fmt.Errorf("集号无效")
	}
	ep, err := GetEpisode(episodeID)
	if err != nil {
		return err
	}
	var conflict Episode
	err = db.Where("drama_id = ? AND episode_no = ? AND id <> ? AND deleted_at IS NULL", ep.DramaID, newNo, episodeID).
		First(&conflict).Error
	if err == nil {
		// 交换集号：冲突集临时挪到负数再互换
		tmp := -conflict.ID
		_ = db.Model(&Episode{}).Where("id = ?", conflict.ID).Update("episode_no", tmp).Error
		if err := db.Model(&Episode{}).Where("id = ?", episodeID).Update("episode_no", newNo).Error; err != nil {
			return err
		}
		return db.Model(&Episode{}).Where("id = ?", conflict.ID).Update("episode_no", ep.EpisodeNo).Error
	}
	if err != gorm.ErrRecordNotFound {
		return err
	}
	return db.Model(&Episode{}).Where("id = ?", episodeID).Update("episode_no", newNo).Error
}

func SoftDeleteEpisode(id int64) error {
	db, err := DB()
	if err != nil {
		return err
	}
	ep, err := GetEpisode(id)
	if err != nil {
		return err
	}
	now := time.Now()
	if err := db.Model(&Episode{}).Where("id = ?", id).Update("deleted_at", now).Error; err != nil {
		return err
	}
	_ = db.Model(&Drama{}).Where("id = ? AND total_episodes > 0", ep.DramaID).
		UpdateColumn("total_episodes", gorm.Expr("total_episodes - 1")).Error
	return nil
}

func ListTopDramas(limit int) ([]Drama, error) {
	db, err := DB()
	if err != nil {
		return nil, err
	}
	if limit <= 0 {
		limit = 10
	}
	var list []Drama
	err = db.Where("deleted_at IS NULL").Order("play_count DESC, id DESC").Limit(limit).Find(&list).Error
	return list, err
}

// BatchSetEpisodePricing：前 freeCount 集免费，其余统一 unlockPrice
func BatchSetEpisodePricing(dramaID int64, freeCount, unlockPrice int) (int64, error) {
	db, err := DB()
	if err != nil {
		return 0, err
	}
	if unlockPrice < 0 {
		unlockPrice = 0
	}
	if freeCount < 0 {
		freeCount = 0
	}
	eps, err := ListEpisodes(dramaID)
	if err != nil {
		return 0, err
	}
	var n int64
	for _, ep := range eps {
		free := ep.EpisodeNo <= freeCount
		price := unlockPrice
		if free {
			price = 0
		}
		if err := db.Model(&Episode{}).Where("id = ?", ep.ID).Updates(map[string]any{
			"is_free":      free,
			"unlock_price": price,
		}).Error; err != nil {
			return n, err
		}
		n++
	}
	_ = db.Model(&Drama{}).Where("id = ?", dramaID).Update("free_episode_count", freeCount).Error
	return n, nil
}

func ListWatchingByUser(userID int64, limit int) ([]WatchProgress, error) {
	return ListContinueWatching(userID, limit)
}

func UpsertProgress(p *WatchProgress) error {
	db, err := DB()
	if err != nil {
		return err
	}
	return db.Clauses(clause.OnConflict{
		Columns:   []clause.Column{{Name: "user_id"}, {Name: "drama_id"}},
		DoUpdates: clause.AssignmentColumns([]string{"episode_id", "episode_no", "position_sec", "updated_at"}),
	}).Create(p).Error
}

func ListContinueWatching(userID int64, limit int) ([]WatchProgress, error) {
	db, err := DB()
	if err != nil {
		return nil, err
	}
	if limit <= 0 {
		limit = 20
	}
	var list []WatchProgress
	err = db.Where("user_id = ?", userID).Order("updated_at DESC").Limit(limit).Find(&list).Error
	return list, err
}

func Favorite(userID, dramaID int64) error {
	db, err := DB()
	if err != nil {
		return err
	}
	return db.Clauses(clause.OnConflict{DoNothing: true}).Create(&DramaFavorite{
		UserID:  userID,
		DramaID: dramaID,
	}).Error
}

func Unfavorite(userID, dramaID int64) error {
	db, err := DB()
	if err != nil {
		return err
	}
	return db.Where("user_id = ? AND drama_id = ?", userID, dramaID).Delete(&DramaFavorite{}).Error
}

func ListFavorites(userID int64) ([]Drama, error) {
	db, err := DB()
	if err != nil {
		return nil, err
	}
	var ids []int64
	if err := db.Model(&DramaFavorite{}).Where("user_id = ?", userID).Order("created_at DESC").Pluck("drama_id", &ids).Error; err != nil {
		return nil, err
	}
	if len(ids) == 0 {
		return []Drama{}, nil
	}
	var list []Drama
	err = db.Where("id IN ? AND deleted_at IS NULL", ids).Find(&list).Error
	return list, err
}

func IsFavorite(userID, dramaID int64) bool {
	db, err := DB()
	if err != nil {
		return false
	}
	var n int64
	db.Model(&DramaFavorite{}).Where("user_id = ? AND drama_id = ?", userID, dramaID).Count(&n)
	return n > 0
}

func BuildFeed(userID int64, page, size int) ([]FeedItem, error) {
	dramas, _, err := ListDramas(page, size, "", nil)
	if err != nil {
		return nil, err
	}
	items := make([]FeedItem, 0, len(dramas))
	for _, d := range dramas {
		epNo := 1
		if userID > 0 {
			if prog, e := getProgress(userID, d.ID); e == nil && prog != nil {
				epNo = prog.EpisodeNo
				if next, e2 := GetEpisodeByNo(d.ID, prog.EpisodeNo+1); e2 == nil && next != nil {
					epNo = next.EpisodeNo
				}
			}
		}
		ep, e := GetEpisodeByNo(d.ID, epNo)
		if e != nil || ep == nil {
			continue
		}
		locked := !IsEpisodeFree(&d, ep) && !HasUnlock(userID, d.ID, ep.ID)
		items = append(items, FeedItem{Drama: d, Episode: *ep, Locked: locked})
	}
	return items, nil
}

func getProgress(userID, dramaID int64) (*WatchProgress, error) {
	db, err := DB()
	if err != nil {
		return nil, err
	}
	var p WatchProgress
	if err := db.Where("user_id = ? AND drama_id = ?", userID, dramaID).First(&p).Error; err != nil {
		return nil, err
	}
	return &p, nil
}

func IsEpisodeFree(d *Drama, ep *Episode) bool {
	if ep.IsFree {
		return true
	}
	return ep.EpisodeNo <= d.FreeEpisodeCount
}

// HasUnlock is implemented in commerce package bridge to avoid import cycle —
// set via function variable.
var HasUnlock = func(userID, dramaID, episodeID int64) bool { return false }

func SearchDramas(keyword string, page, size int) ([]Drama, int64, error) {
	db, err := DB()
	if err != nil {
		return nil, 0, err
	}
	if page < 1 {
		page = 1
	}
	if size < 1 || size > 50 {
		size = 20
	}
	q := db.Model(&Drama{}).Where("deleted_at IS NULL AND status = 1")
	if keyword != "" {
		like := "%" + keyword + "%"
		q = q.Where("title LIKE ? OR description LIKE ? OR tags LIKE ? OR category LIKE ?", like, like, like, like)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var list []Drama
	err = q.Order("play_count DESC, id DESC").Offset((page - 1) * size).Limit(size).Find(&list).Error
	return list, total, err
}

// 本地联调静态根：封面/片源均走 Gateway StaticFS，避免外网图床超时导致剧场灰封面。
const localStaticBase = "http://127.0.0.1:28880"

func localCoverURL(n int) string {
	if n < 1 {
		n = 1
	}
	// 预置 drama1..drama4.jpg，超出则循环
	idx := ((n - 1) % 4) + 1
	return fmt.Sprintf("%s/covers/drama%d.jpg", localStaticBase, idx)
}

// ensureLocalCoverFiles 生成本地封面（storage 被 gitignore），避免依赖外网图床。
func ensureLocalCoverFiles() {
	dir := "src/storage/covers"
	_ = os.MkdirAll(dir, 0o755)
	palette := []color.RGBA{
		{R: 0x1F, G: 0x6F, B: 0x8B, A: 0xFF},
		{R: 0x3D, G: 0x5A, B: 0x80, A: 0xFF},
		{R: 0xEE, G: 0x6C, B: 0x4D, A: 0xFF},
		{R: 0x2A, G: 0x9D, B: 0x8F, A: 0xFF},
	}
	for i, c := range palette {
		path := filepath.Join(dir, fmt.Sprintf("drama%d.jpg", i+1))
		if st, err := os.Stat(path); err == nil && st.Size() > 0 {
			continue
		}
		img := image.NewRGBA(image.Rect(0, 0, 640, 960))
		for y := 0; y < 960; y++ {
			for x := 0; x < 640; x++ {
				img.SetRGBA(x, y, c)
			}
		}
		f, err := os.Create(path)
		if err != nil {
			continue
		}
		_ = jpeg.Encode(f, img, &jpeg.Options{Quality: 82})
		_ = f.Close()
	}
}

func EnsureSeed() error {
	ensureLocalCoverFiles()
	db, err := DB()
	if err != nil {
		return err
	}
	_ = ensureCategoryTable(db)
	for i, name := range []string{"甜宠", "古装", "青春"} {
		_ = db.Clauses(clause.OnConflict{DoNothing: true}).Create(&CategoryCatalog{Name: name, SortOrder: i + 1}).Error
	}
	var n int64
	if err := db.Model(&Drama{}).Count(&n).Error; err != nil {
		return err
	}
	if n == 0 {
		// 本地静态片源（Gateway StaticFS: /videos/*），保证 iOS AVPlayer 有 Content-Length
		samples := []string{
			localStaticBase + "/videos/sample_a.mp4",
			localStaticBase + "/videos/sample_b.mp4",
		}
		titles := []struct {
			Title, Category, Desc string
		}{
			{"重生之闪婚总裁", "甜宠", "她重生归来，这次绝不认栽。"},
			{"冷王的小仵作", "古装", "验尸台前，情丝暗生。"},
			{"校园风云录", "青春", "年级第一与转校生的故事。"},
		}
		for i, t := range titles {
			d := &Drama{
				Title:            t.Title,
				CoverURL:         localCoverURL(i + 1),
				Description:      t.Desc,
				Category:         t.Category,
				Tags:             t.Category + ",热播",
				FreeEpisodeCount: 3,
				BundlePrice:      80,
				Status:           1,
			}
			if err := db.Create(d).Error; err != nil {
				return err
			}
			for ep := 1; ep <= 12; ep++ {
				url := samples[(i*12+ep)%len(samples)]
				e := &Episode{
					DramaID:     d.ID,
					EpisodeNo:   ep,
					Title:       fmt.Sprintf("第%d集", ep),
					VideoURL:    url,
					CoverURL:    d.CoverURL,
					Duration:    60,
					IsFree:      ep <= 3,
					UnlockPrice: 10,
				}
				if err := db.Create(e).Error; err != nil {
					return err
				}
			}
			_ = db.Model(d).Update("total_episodes", 12).Error
		}
	}
	return repairExternalCoverURLs(db)
}

// repairExternalCoverURLs 把历史 picsum 等外网封面纠到本地 /covers，保证联调可离线出图。
func repairExternalCoverURLs(db *gorm.DB) error {
	var list []Drama
	if err := db.Where(
		"cover_url LIKE ? OR cover_url LIKE ? OR cover_url = ''",
		"%picsum.photos%",
		"%fastly.picsum%",
	).Find(&list).Error; err != nil {
		return err
	}
	for _, d := range list {
		url := localCoverURL(int(d.ID))
		if err := db.Model(&Drama{}).Where("id = ?", d.ID).Update("cover_url", url).Error; err != nil {
			return err
		}
		if err := db.Model(&Episode{}).Where("drama_id = ?", d.ID).Update("cover_url", url).Error; err != nil {
			return err
		}
	}
	return nil
}
