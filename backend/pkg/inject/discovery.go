package inject

import (
	"context"

	"github.com/mutezebra/tiktok/pkg/discovery"
	"github.com/mutezebra/tiktok/pkg/log"
)

type Registry struct {
	reg      *discovery.Registry
	Key      string
	Prefix   string
	TTL      int64
	Addr     string
	EndPoint string
}

func NewRegistry(registry *Registry) *Registry {
	reg, err := discovery.NewRegistry(registry.Addr, registry.Key, registry.TTL, registry.EndPoint, registry.Prefix)
	if err != nil {
		log.LogrusObj.Panic(err)
		return nil
	}
	return &Registry{reg: reg}
}

func (r *Registry) Close() {
	r.reg.Close()
}

func (r *Registry) Register(ctx context.Context) error {
	return r.reg.Register(ctx)
}

func (r *Registry) MustRegister(ctx context.Context) {
	r.reg.MustRegister(ctx)
}

type Resolver struct {
	*discovery.Resolver
}

func NewResolver(endpoint string) (*Resolver, error) {
	re, err := discovery.NewResolver(endpoint)
	return &Resolver{re}, err
}
