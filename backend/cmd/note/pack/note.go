package pack

import (
	"time"

	"github.com/ozline/tiktok/cmd/note/dal/db"
	"github.com/ozline/tiktok/kitex_gen/note"
)

func Note(data *db.Note) *note.Note {
	if data == nil {
		return nil
	}
	return &note.Note{
		Id:        data.Id,
		VideoId:   data.VideoID,
		UserId:    data.UserID,
		Content:   data.Content,
		Type:      data.Type,
		CreatedAt: data.CreatedAt.Format("2006-01-02 15:04:05"),
		UpdatedAt: data.UpdatedAt.Format("2006-01-02 15:04:05"),
	}
}

func NoteList(data []db.Note) []*note.Note {
	noteList := make([]*note.Note, 0, len(data))
	for i := 0; i < len(data); i++ {
		noteList = append(noteList, Note(&data[i]))
	}
	return noteList
}

