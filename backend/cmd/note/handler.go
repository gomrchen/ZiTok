package main

import (
	"context"

	"github.com/cloudwego/kitex/pkg/klog"
	"github.com/ozline/tiktok/cmd/note/pack"
	"github.com/ozline/tiktok/cmd/note/service"
	note "github.com/ozline/tiktok/kitex_gen/note"
	"github.com/ozline/tiktok/pkg/errno"
)

// NoteServiceImpl implements the last service interface defined in the IDL.
type NoteServiceImpl struct{}

// CreateNote implements the NoteServiceImpl interface.
func (s *NoteServiceImpl) CreateNote(ctx context.Context, req *note.CreateNoteRequest) (resp *note.CreateNoteResponse, err error) {
	resp = new(note.CreateNoteResponse)

	if len(req.Content) == 0 {
		resp.Base = pack.BuildBaseResp(errno.ParamError)
		return resp, nil
	}

	noteData, err := service.NewNoteService(ctx).CreateNote(req)
	if err != nil {
		klog.Error(err)
		resp.Base = pack.BuildBaseResp(err)
		return resp, nil
	}

	resp.Base = pack.BuildBaseResp(nil)
	resp.Note = pack.Note(noteData)
	return resp, nil
}

// GetNote implements the NoteServiceImpl interface.
func (s *NoteServiceImpl) GetNote(ctx context.Context, req *note.GetNoteRequest) (resp *note.GetNoteResponse, err error) {
	resp = new(note.GetNoteResponse)

	noteData, err := service.NewNoteService(ctx).GetNote(req)
	if err != nil {
		klog.Error(err)
		resp.Base = pack.BuildBaseResp(err)
		return resp, nil
	}

	resp.Base = pack.BuildBaseResp(nil)
	resp.Note = pack.Note(noteData)
	return resp, nil
}

// GetNotesByVideo implements the NoteServiceImpl interface.
func (s *NoteServiceImpl) GetNotesByVideo(ctx context.Context, req *note.GetNotesByVideoRequest) (resp *note.GetNotesByVideoResponse, err error) {
	resp = new(note.GetNotesByVideoResponse)

	notes, err := service.NewNoteService(ctx).GetNotesByVideo(req)
	if err != nil {
		klog.Error(err)
		resp.Base = pack.BuildBaseResp(err)
		return resp, nil
	}

	resp.Base = pack.BuildBaseResp(nil)
	resp.Notes = pack.NoteList(notes)
	return resp, nil
}

// GetNotesByUser implements the NoteServiceImpl interface.
func (s *NoteServiceImpl) GetNotesByUser(ctx context.Context, req *note.GetNotesByUserRequest) (resp *note.GetNotesByUserResponse, err error) {
	resp = new(note.GetNotesByUserResponse)

	notes, err := service.NewNoteService(ctx).GetNotesByUser(req)
	if err != nil {
		klog.Error(err)
		resp.Base = pack.BuildBaseResp(err)
		return resp, nil
	}

	resp.Base = pack.BuildBaseResp(nil)
	resp.Notes = pack.NoteList(notes)
	return resp, nil
}

// UpdateNote implements the NoteServiceImpl interface.
func (s *NoteServiceImpl) UpdateNote(ctx context.Context, req *note.UpdateNoteRequest) (resp *note.UpdateNoteResponse, err error) {
	resp = new(note.UpdateNoteResponse)

	if len(req.Content) == 0 {
		resp.Base = pack.BuildBaseResp(errno.ParamError)
		return resp, nil
	}

	err = service.NewNoteService(ctx).UpdateNote(req)
	if err != nil {
		klog.Error(err)
		resp.Base = pack.BuildBaseResp(err)
		return resp, nil
	}

	resp.Base = pack.BuildBaseResp(nil)
	return resp, nil
}

// DeleteNote implements the NoteServiceImpl interface.
func (s *NoteServiceImpl) DeleteNote(ctx context.Context, req *note.DeleteNoteRequest) (resp *note.DeleteNoteResponse, err error) {
	resp = new(note.DeleteNoteResponse)

	err = service.NewNoteService(ctx).DeleteNote(req)
	if err != nil {
		klog.Error(err)
		resp.Base = pack.BuildBaseResp(err)
		return resp, nil
	}

	resp.Base = pack.BuildBaseResp(nil)
	return resp, nil
}

