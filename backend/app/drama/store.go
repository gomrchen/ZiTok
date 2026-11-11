package drama

import (
	"fmt"
	"image"
	"image/color"
	"image/jpeg"
	"os"
	"path/filepath"
	"sync"

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
	q := db.Model(&Drama{}).Where("deleted_at IS NULL")
	if status == nil {
		q = q.Where("status = 1")
	} else if *status != StatusAll {
		q = q.Where("status = ?", *status)
	}
	if category != "" {
		q = q.Where("category = ?", category)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var list []Drama
	err = q.Order("play_count DESC, id DESC").Offset((page - 1) * size).Limit(size).Find(&list).Error
	return list, total, err
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
	return db.Model(&Drama{}).Where("id = ?", id).Update("status", 2).Error
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
