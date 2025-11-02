package discovery

import (
	"context"
	"time"

	"github.com/pkg/errors"
	etcd "go.etcd.io/etcd/client/v3"

	"github.com/mutezebra/tiktok/pkg/log"
)

type Registry struct {
	Addr   string
	TTL    int64
	Key    string
	Prefix string

	leaseID       etcd.LeaseID
	client        *etcd.Client
	keepAliveChan <-chan *etcd.LeaseKeepAliveResponse
}

func NewRegistry(addr string, key string, ttl int64, endPoint string, prefix string) (*Registry, error) {
	if len(prefix) < 1 {
		return nil, errors.New("the size of prefix must be 0 or 1")
	}
	pre := prefix
	if prefix[len(prefix)-1] != '/' {
		pre += "/"
	}
	if ttl == 0 {
		ttl = 15
	}
	client, err := newClient(endPoint)
	if err != nil {
		return nil, errors.WithMessage(err, "failed to create the etcd client")
	}
	return &Registry{
		Addr:          addr,
		TTL:           ttl,
		Key:           key,
		Prefix:        pre,
		leaseID:       0,
		keepAliveChan: nil,
		client:        client,
	}, nil
}

// Register registers the service to etcd and starts the keepAlive goroutine.
func (r *Registry) Register(ctx context.Context) error {
	grantCtx, cn := context.WithTimeout(ctx, 1*time.Second)
	defer cn()
	lease, err := r.client.Grant(grantCtx, r.TTL)
	if err != nil {
		return errors.WithMessage(err, "grant lease failed")
	}
	r.leaseID = lease.ID

	putCtx, cancel := context.WithTimeout(ctx, 1*time.Second)
	defer cancel()
	key := r.Key
	if r.Prefix != "" {
		key = r.Prefix + r.Key
	}
	_, err = r.client.Put(putCtx, key, r.Addr, etcd.WithLease(r.leaseID))
	if err != nil {
		_ = r.client.Close()
		return errors.WithMessage(err, "etcd client put server failed")
	}
	go r.keepAlive(ctx)
	return nil
}

func (r *Registry) MustRegister(ctx context.Context) {
	if err := r.Register(ctx); err != nil {
		log.LogrusObj.Panic(err)
	}
}

// keepAlive maintains the service registration in etcd by sending keep-alive messages.
func (r *Registry) keepAlive(ctx context.Context) {
	childCtx, cancel := context.WithCancel(ctx)
	defer cancel()
	r.keepAliveChan, _ = r.client.KeepAlive(childCtx, r.leaseID)
	defer func() { _ = r.client.Close() }()
	for {
		select {
		case <-r.keepAliveChan:
			break
		case <-time.After(time.Duration(r.TTL) * time.Second):
			log.LogrusObj.Errorf("the service whose key is %s and address is %s loses its heartbeat in etcd", r.Key, r.Addr)
			return
		}
	}
}

func (r *Registry) Close() {
	_ = r.client.Close()
}
