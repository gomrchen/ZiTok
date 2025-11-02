package repository

type VideoCacheRepository interface {
	GetPopularVids() []int64
	SetVideoViews(vid int64, views int32) error
	IncrVideoViews(vid int64) error
	EnablePopularRanking()
	ViewsKVS() map[int64]int32
	ViewKeyExist(vid int64) bool
}
