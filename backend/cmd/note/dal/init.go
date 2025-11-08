package dal

import (
	"github.com/ozline/tiktok/cmd/note/dal/cache"
	"github.com/ozline/tiktok/cmd/note/dal/db"
)

func Init() {
	db.Init()
	cache.Init()
}

