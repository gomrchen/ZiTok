package service

import "context"

type NoteService struct {
	ctx context.Context
}

// NewNoteService new NoteService
func NewNoteService(ctx context.Context) *NoteService {
	return &NoteService{ctx: ctx}
}

