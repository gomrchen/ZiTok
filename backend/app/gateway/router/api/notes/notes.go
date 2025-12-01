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
				_note := _v1.Group("/note", _noteMw()...)
				_note.POST("/create", append(_createNoteMw(), notes.CreateNote)...)
				_note.POST("/delete", append(_deleteNoteMw(), notes.DeleteNote)...)
				_note.POST("/like", append(_likeNoteMw(), notes.LikeNote)...)
				_note.POST("/favorite", append(_favoriteNoteMw(), notes.FavoriteNote)...)
				_note.GET("/video", append(_getVideoNotesMw(), notes.GetVideoNotes)...)
				_note.GET("/user", append(_getUserNotesMw(), notes.GetUserNotes)...)
				_note.GET("", append(_getNotesMw(), notes.GetNotes)...)
			}
		}
	}
}
