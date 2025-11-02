package log

import (
	errors2 "errors"
	"fmt"
	"strings"
	"sync"

	"github.com/pkg/errors"
	"github.com/sirupsen/logrus"
)

type Logger struct {
	*logrus.Logger
	pool sync.Pool
}

// Panic refactors the panic function within logrus. It records
// the stack info and outputs it to logrus`s 'Out'
func (l *Logger) Panic(v any) {
	str := l.formatCallStack(v)
	l.Logger.Panic(*str)
}

// Error refactors the error function within logrus. It records
// the stack info and outputs it to logrus`s 'Out'
func (l *Logger) Error(v any) {
	str := l.formatCallStack(v)
	l.Logger.Error(*str)
}

func (l *Logger) formatCallStack(v any) *string {
	builder := l.get()
	builder.WriteString(fmt.Sprintf("%v  \n", v))

	err, ok := v.(error)
	if ok {
		originErr := errors.Cause(err)
		if !errors2.Is(originErr, err) {
			builder.WriteString(fmt.Sprintf(" originl error: %v  \n the full trace: %+v\n", errors.Cause(err), err))
		}
	}

	str := builder.String()

	l.put(builder)
	return &str
}

func (l *Logger) get() *strings.Builder {
	return l.pool.Get().(*strings.Builder)
}

func (l *Logger) put(str *strings.Builder) {
	str.Reset()
	l.pool.Put(str)
}

// Restore replaces "\\n" with "\n" in the panic msg.
func Restore(msg string) string {
	return strings.ReplaceAll(strings.ReplaceAll(msg, "\\n", "\n"), "\\t", "\t")
}
