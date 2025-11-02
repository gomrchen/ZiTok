package discovery

import (
	"time"

	etcd "go.etcd.io/etcd/client/v3"
)

func newClient(endpoint string) (*etcd.Client, error) {
	client, err := etcd.New(etcd.Config{
		Endpoints:   []string{endpoint},
		DialTimeout: 5 * time.Second,
	})
	if err != nil {
		return nil, err
	}
	return client, nil
}
