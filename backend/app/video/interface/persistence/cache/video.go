package cache

import (
	"context"
	"fmt"
	"strconv"
	"sync"

	"github.com/redis/go-redis/v9"

	"github.com/mutezebra/tiktok/pkg/constants"
	"github.com/mutezebra/tiktok/pkg/log"
)

type VideoCacheRepo struct {
	ctx    context.Context
	client *redis.Client

	popularRankModel *popularRankModel
}

func NewVideoCacheRepo() *VideoCacheRepo {
	if RedisClient == nil {
		panic("redis have not init")
	}

	return &VideoCacheRepo{
		ctx:    context.Background(),
		client: RedisClient,

		popularRankModel: &popularRankModel{
			enablePopularRanking: false,
			maxSizeOfPopularSet:  127,
			minPopularVideoViews: 0,
			rankKey:              constants.CacheVideoPopularKey,
			popularVids:          make([]int64, 0, constants.CacheVideoPopularVideosSize),
			refreshInterval:      constants.CacheVideoPopularRefreshInterval,

			ctx:    context.Background(),
			client: RedisClient,
			mu:     sync.RWMutex{},
		},
	}
}

func (cache *VideoCacheRepo) GetPopularVids() []int64 {
	return cache.popularRankModel.GetPopularVids()
}

func (cache *VideoCacheRepo) SetVideoViews(vid int64, views int32) error {
	key := fmt.Sprintf("%s%d", constants.CacheVideoViewKeyPrefix, vid)
	err := cache.client.SetEx(cache.ctx, key, views, constants.CacheVideoViewExpireTime).Err()
	if err != nil {
		return err
	}
	if cache.popularRankModel.enablePopularRanking {
		cache.popularRankModel.AddToRank(vid, views)
	}
	return nil
}

func (cache *VideoCacheRepo) IncrVideoViews(vid int64) error {
	key := fmt.Sprintf("%s%d", constants.CacheVideoViewKeyPrefix, vid)
	views, err := cache.client.Incr(cache.ctx, key).Result()
	if err != nil {
		return err
	}
	if cache.popularRankModel.enablePopularRanking {
		cache.popularRankModel.AddToRank(vid, int32(views))
	}
	return cache.client.Expire(cache.ctx, key, constants.CacheVideoViewExpireTime).Err()
}

func (cache *VideoCacheRepo) EnablePopularRanking() {
	cache.popularRankModel.enablePopularRanking = true
	go cache.popularRankModel.TimedRefresh()
}

func (cache *VideoCacheRepo) ViewKeyExist(vid int64) bool {
	return cache.client.Exists(cache.ctx, fmt.Sprintf("%s%d", constants.CacheVideoViewKeyPrefix, vid)).Val() != 0
}

func (cache *VideoCacheRepo) ViewsKVS() map[int64]int32 {
	var cursor uint64
	result := make(map[int64]int32)
	vidStart := len(constants.CacheVideoViewKeyPrefix)
	for {
		var keys []string
		var err error
		keys, cursor, err = cache.client.Scan(cache.ctx, cursor, constants.CacheVideoViewKeyPrefix+"*", 10).Result()
		if err != nil {
			log.LogrusObj.Error(fmt.Sprintf("scan views failed,cause:%s", err))
		}
		for _, key := range keys {
			views, _ := cache.client.Get(cache.ctx, key).Int()
			vid, _ := strconv.ParseInt(key[vidStart:], 10, 64)
			result[vid] = int32(views)
		}
		if cursor == 0 {
			break
		}
	}

	if len(result) == 0 {
		return nil
	}
	return result
}
