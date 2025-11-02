package trace

import (
	"context"
	"strings"

	"github.com/bytedance/gopkg/cloud/metainfo"
)

type MDReaderWriter struct {
	ctx context.Context
}

func (m *MDReaderWriter) Set(key, val string) {
	key = strings.ToLower(key)
	m.ctx = metainfo.WithPersistentValue(m.ctx, key, val)
}

func (m *MDReaderWriter) ForeachKey(handler func(key, val string) error) error {
	values := metainfo.GetAllPersistentValues(m.ctx)
	for k, v := range values {
		if err := handler(k, v); err != nil {
			return err
		}
	}
	return nil
}
