package model

import (
	"context"
)

type Resolver interface {
	Resolve(ctx context.Context, key string) (string, error)
	ResolveWithPrefix(ctx context.Context, prefix string) ([]string, error)
	Close()
}
