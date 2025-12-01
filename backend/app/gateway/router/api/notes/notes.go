package notes

import (
	"github.com/cloudwego/hertz/pkg/app/server"
	notes "github.com/yxrxy/videoHub/app/gateway/handler/api/notes"
)

// Register register routes for notes API
func Register(r *server.Hertz) {
	root := r.Group("/", rootMw()...)
	{
		_api := root.Group("/api", _apiMw()...)
		{
			_v1 := _api.Group("/v1", _v1Mw()...)
			{
				// 需要认证的路由
				authGroup := _v1.Group("/note", authMw()...)
				{
					authGroup.POST("/create", append(_createNoteMw(), notes.CreateNote)...)
					authGroup.POST("/delete", append(_deleteNoteMw(), notes.DeleteNote)...)
					authGroup.POST("/like", append(_likeNoteMw(), notes.LikeNote)...)
					authGroup.POST("/favorite", append(_favoriteNoteMw(), notes.FavoriteNote)...)
				}

				// 公开路由（不需要认证）
				publicGroup := _v1.Group("/note", publicMw()...)
				{
					publicGroup.GET("/video", append(_getVideoNotesMw(), notes.GetVideoNotes)...)
					publicGroup.GET("/user", append(_getUserNotesMw(), notes.GetUserNotes)...)
					// 添加对/api/v1/note路径的支持，根据type参数转发
					publicGroup.GET("", append(_getVideoNotesMw(), notes.GetNotes)...)
				}
			}
		}
	}
}

// 中间件函数在middleware.go中实现
