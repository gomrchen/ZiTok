package service

import (
	"github.com/ozline/tiktok/cmd/note/dal/db"
	"github.com/ozline/tiktok/kitex_gen/note"
	"github.com/ozline/tiktok/pkg/errno"
	"github.com/ozline/tiktok/pkg/utils"
)

func (s *NoteService) GetNote(req *note.GetNoteRequest) (*db.Note, error) {
	if _, err := utils.CheckToken(req.Token); err != nil {
		return nil, errno.AuthorizationFailedError
	}

	note, err := db.GetNoteByID(s.ctx, req.NoteId)
	if err != nil {
		return nil, errno.NoteNotFoundError
	}

	return note, nil
}

func (s *NoteService) GetNotesByVideo(req *note.GetNotesByVideoRequest) ([]db.Note, error) {
	if _, err := utils.CheckToken(req.Token); err != nil {
		return nil, errno.AuthorizationFailedError
	}

	notes, err := db.GetNotesByVideoID(s.ctx, req.VideoId)
	if err != nil {
		return nil, err
	}

	return notes, nil
}

func (s *NoteService) GetNotesByUser(req *note.GetNotesByUserRequest) ([]db.Note, error) {
	if _, err := utils.CheckToken(req.Token); err != nil {
		return nil, errno.AuthorizationFailedError
	}

	notes, err := db.GetNotesByUserID(s.ctx, req.UserId)
	if err != nil {
		return nil, err
	}

	return notes, nil
}

