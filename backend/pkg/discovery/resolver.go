package discovery

import (
	"context"

	"github.com/pkg/errors"
	etcd "go.etcd.io/etcd/client/v3"
)

type Resolver struct {
	client *etcd.Client
}

func NewResolver(endpoint string) (*Resolver, error) {
	client, err := newClient(endpoint)
	if err != nil {
		return nil, errors.WithMessage(err, "failed to create the etcd client")
	}
	return &Resolver{client: client}, nil
}

// Resolve uses the etcd client to get the value associated with the key from the etcd store.
// It returns the value as a string and an error if any occurred during the operation.
func (r *Resolver) Resolve(ctx context.Context, key string) (string, error) {
	getCtx, cancel := context.WithCancel(ctx)
	defer cancel()
	res, err := r.client.Get(getCtx, key, etcd.WithLimit(1))
	if err != nil {
		return "", errors.WithMessage(err, "etcd resolve failed")
	}
	value := string(res.Kvs[0].Value)
	return value, nil
}

// ResolveWithPrefix uses the etcd client to get all keys that start with the given prefix from the etcd store.
// It returns a slice of strings containing the values of the keys and an error if any occurred during the operation.
func (r *Resolver) ResolveWithPrefix(ctx context.Context, prefix string) ([]string, error) {
	getCtx, cancel := context.WithCancel(ctx)
	defer cancel()
	res, err := r.client.Get(getCtx, prefix, etcd.WithPrefix())
	if err != nil {
		return nil, errors.WithMessage(err, "etcd resolve with prefix failed")
	}
	values := make([]string, 0, len(res.Kvs))
	for _, value := range res.Kvs {
		values = append(values, string(value.Value))
	}
	return values, nil
}

func (r *Resolver) Close() {
	_ = r.client.Close()
}
