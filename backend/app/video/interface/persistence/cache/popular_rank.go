package cache

import (
	"context"
	"strconv"
	"sync"
	"time"

	"github.com/redis/go-redis/v9"

	"github.com/mutezebra/tiktok/pkg/log"
)

type popularRankModel struct {
	enablePopularRanking bool
	rankKey              string
	maxSizeOfPopularSet  int32 // 建议不要超过128，可以使redis使用ziplist结构来保证更高的效率
	minPopularVideoViews int32
	refreshInterval      time.Duration
	popularVids          []int64 // 最多不能超过127
	ctx                  context.Context
	client               *redis.Client
	mu                   sync.RWMutex
}

func (p *popularRankModel) AddToRank(vid int64, views int32) {
	if views <= p.minPopularVideoViews {
		return
	}

	member := redis.Z{
		Score:  float64(views),
		Member: vid,
	}

	p.mu.Lock()
	defer p.mu.Unlock()

	pipe := p.client.TxPipeline()
	pipe.ZAdd(p.ctx, p.rankKey, member)
	zcard := pipe.ZCard(p.ctx, p.rankKey)
	_, err := pipe.Exec(p.ctx)
	p.handleError("execute transaction failed cause:", err)

	if zcard.Val() < int64(p.maxSizeOfPopularSet) {
		return
	}

	minViews, err := p.client.ZRemRangeByRank(p.ctx, p.rankKey, 0, 0).Result()
	p.handleError("del a member from video:popular:primary failed cause:", err)
	if err != nil {
		p.minPopularVideoViews = int32(minViews)
	}
}

func (p *popularRankModel) GetPopularVids() []int64 {
	vids := make([]int64, len(p.popularVids))
	copy(vids, p.popularVids)
	return vids
}

func (p *popularRankModel) TimedRefresh() {
	interval := p.refreshInterval
	for {
		p.updatePopularVids()
		time.Sleep(interval)
	}
}

func (p *popularRankModel) updatePopularVids() {
	result, err := p.client.ZRevRange(p.ctx, p.rankKey, 0, 49).Result()
	p.handleError("get popular vids failed cause:", err)
	vids := make([]int64, 0, len(p.popularVids))
	for _, v := range result {
		i, err := strconv.ParseInt(v, 10, 64)
		p.handleError("parse int failed cause:", err)
		vids = append(vids, i)
	}
	p.popularVids = vids
}

func (p *popularRankModel) handleError(message string, err error) {
	if err != nil {
		log.LogrusObj.Warning(message, err)
	}
}
