package pack

import (
	errno2 "github.com/mutezebra/tiktok/pkg/errno"
	"github.com/mutezebra/tiktok/pkg/log"
)

// ReturnError returns only the basic information to the front-end,
// and the detailed error information is recorded in the log
func ReturnError(errno errno2.Errno, err error) error {
	log.LogrusObj.Error(err)
	return errno
}
