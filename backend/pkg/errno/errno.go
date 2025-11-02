package errno

import (
	"fmt"

	"github.com/cloudwego/kitex/pkg/kerrors"
)

type Errno interface {
	BizStatusCode() int32
	BizMessage() string
	BizExtra() map[string]string
	Error() string
}

type errno struct {
	code int32
	msg  string
}

func (e *errno) Error() string {
	return fmt.Sprintf("Code: %d, Msg: %s", e.BizStatusCode(), e.BizMessage())
}

func (e *errno) BizStatusCode() int32 {
	return e.code
}

func (e *errno) BizMessage() string {
	return e.msg
}

func (e *errno) BizExtra() map[string]string {
	// do nothing
	return nil
}

func New(code int32, msg string) Errno {
	return kerrors.NewBizStatusError(code, msg)
}

var Success = New(200, "operate success")

type withMessage struct {
	code  int32
	msg   string
	cause error
}

func (w *withMessage) Error() string {
	return fmt.Sprintf("Code: %d, Msg: %s", w.BizStatusCode(), w.BizMessage())
}

func (w *withMessage) BizStatusCode() int32 {
	return w.code
}

func (w *withMessage) BizMessage() string {
	return fmt.Sprintf("%s cause: %s", w.msg, w.cause.Error())
}

func (w *withMessage) BizExtra() map[string]string {
	return nil
}

func (w *withMessage) Cause() error {
	return w.cause
}

func WithError(errno Errno, err error) Errno {
	if err == nil {
		return errno
	}
	if errno == nil {
		return nil
	}

	return &withMessage{
		code:  errno.BizStatusCode(),
		msg:   errno.Error(),
		cause: err,
	}
}

func Convert(err error) Errno {
	if err == nil {
		return Success
	}
	return &errno{
		code: -1,
		msg:  err.Error(),
	}
}
