package pack

import (
	errno2 "github.com/mutezebra/tiktok/pkg/errno"
	"github.com/mutezebra/tiktok/pkg/log"
)

// ReturnError records the detailed error information in the log
// and returns only the basic information to the front-end
func ReturnError(errno errno2.Errno, err error) error {
	log.LogrusObj.Error(errno2.WithError(errno, err))
	return errno
}
