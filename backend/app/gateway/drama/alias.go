// Package drama 兼容层：领域实现已抽离到 app/drama，Gateway HTTP 继续复用同一套 store。
package drama

import core "github.com/yxrxy/videoHub/app/drama"

type (
	Drama         = core.Drama
	Episode       = core.Episode
	WatchProgress = core.WatchProgress
	DramaFavorite = core.DramaFavorite
	FeedItem      = core.FeedItem
	PlayInfo      = core.PlayInfo
)

var (
	DB                   = core.DB
	ListDramas           = core.ListDramas
	GetDrama             = core.GetDrama
	ListEpisodes         = core.ListEpisodes
	GetEpisode           = core.GetEpisode
	GetEpisodeByNo       = core.GetEpisodeByNo
	CreateDrama          = core.CreateDrama
	UpdateDrama          = core.UpdateDrama
	CreateEpisode        = core.CreateEpisode
	UpdateEpisode        = core.UpdateEpisode
	SoftDeleteDrama      = core.SoftDeleteDrama
	UpsertProgress       = core.UpsertProgress
	ListContinueWatching = core.ListContinueWatching
	Favorite             = core.Favorite
	Unfavorite           = core.Unfavorite
	ListFavorites        = core.ListFavorites
	IsFavorite           = core.IsFavorite
	BuildFeed            = core.BuildFeed
	IsEpisodeFree        = core.IsEpisodeFree
	SearchDramas         = core.SearchDramas
	EnsureSeed           = core.EnsureSeed
	StatusAll            = core.StatusAll
)

// HasUnlock 由 commerce 包在 init 时注入到 app/drama.HasUnlock
var HasUnlock = func(userID, dramaID, episodeID int64) bool {
	return core.HasUnlock(userID, dramaID, episodeID)
}
