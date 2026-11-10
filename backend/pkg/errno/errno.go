/*
Copyright 2024 The west2-online Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

// DO NOT EDIT

package errno

import (
	"errors"
	"fmt"
	"regexp"
	"strconv"
	"strings"
)

var bizErrPattern = regexp.MustCompile(`biz error:\s*\[(\d+)\]\s*(.+)`)

type ErrNo struct {
	ErrorCode int64
	ErrorMsg  string
}

func (e ErrNo) Error() string {
	return fmt.Sprintf("[%d] %s", e.ErrorCode, e.ErrorMsg)
}

func NewErrNo(code int64, msg string) ErrNo {
	return ErrNo{
		ErrorCode: code,
		ErrorMsg:  msg,
	}
}

func Errorf(code int64, template string, args ...interface{}) ErrNo {
	return ErrNo{
		ErrorCode: code,
		ErrorMsg:  fmt.Sprintf(template, args...),
	}
}

// WithMessage will replace default msg to new
func (e ErrNo) WithMessage(msg string) ErrNo {
	e.ErrorMsg = msg
	return e
}

// WithError will add error msg after Message
func (e ErrNo) WithError(err error) ErrNo {
	e.ErrorMsg = e.ErrorMsg + ", " + err.Error()
	return e
}

// ConvertErr convert error to ErrNo
// in Default user ServiceErrorCode
func ConvertErr(err error) ErrNo {
	if err == nil {
		return Success
	}
	errno := ErrNo{}
	if errors.As(err, &errno) {
		// Kitex 常把业务 ErrNo 包进 InternalServiceError.WithError
		if unwrapped := unwrapBizErrNo(errno); unwrapped != nil {
			return *unwrapped
		}
		return errno
	}

	if unwrapped := parseBizErrMsg(err.Error()); unwrapped != nil {
		return *unwrapped
	}

	s := InternalServiceError
	s.ErrorMsg = err.Error()
	return s
}

func unwrapBizErrNo(e ErrNo) *ErrNo {
	if e.ErrorCode != InternalServiceErrorCode {
		return nil
	}
	return parseBizErrMsg(e.ErrorMsg)
}

func parseBizErrMsg(msg string) *ErrNo {
	m := bizErrPattern.FindStringSubmatch(msg)
	if len(m) != 3 {
		return nil
	}
	code, err := strconv.ParseInt(m[1], 10, 64)
	if err != nil {
		return nil
	}
	text := strings.TrimSpace(m[2])
	if text == "" {
		return nil
	}
	return &ErrNo{ErrorCode: code, ErrorMsg: text}
}
